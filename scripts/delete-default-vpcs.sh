#!/usr/bin/env bash
#
# Delete the default VPC in every enabled region of the current AWS account.
#
# For each default VPC the script removes its dependencies in order:
#   1. Detach and delete internet gateways
#   2. Delete subnets
#   3. Delete the VPC (the default route table, NACL and security group go with it)
#
# A VPC is skipped, before anything is deleted, if it still has network
# interfaces (EC2 instances, load balancers, Lambda ENIs and so on) or any
# other resource that would block deletion: non-default security groups,
# route tables or network ACLs, VPC endpoints, or an attached VPN gateway.
# Regions that can't be queried (for example, denied by an SCP) are skipped.
# Regions passed with --skip-region are left alone; an unknown or disabled
# region name is an error, so a typo can't delete a VPC you meant to keep.
#
# Usage:
#   ./scripts/delete-default-vpcs.sh            # dry run: shows what would be deleted
#   ./scripts/delete-default-vpcs.sh --execute  # deletes, after confirmation
#   ./scripts/delete-default-vpcs.sh --execute --yes  # deletes, no prompt
#   ./scripts/delete-default-vpcs.sh --skip-region us-east-1,eu-west-1  # leave these regions alone
#   ./scripts/delete-default-vpcs.sh --skip-region us-east-1 --skip-region eu-west-1  # same, repeated
#
# Pass credentials the usual way (AWS_PROFILE, environment variables, SSO).
# A deleted default VPC can be recreated with: aws ec2 create-default-vpc --region <region>
#
# --- end of help ---

set -euo pipefail

EXECUTE=false
ASSUME_YES=false
SKIP_REGIONS=""

usage() {
  sed -n '2,/^# --- end of help ---$/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

add_skip_regions() {
  [[ -n "$1" ]] || { echo "--skip-region requires a region" >&2; usage 1; }
  SKIP_REGIONS="$SKIP_REGIONS ${1//,/ }"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=true ;;
    --yes|-y)  ASSUME_YES=true ;;
    --skip-region) add_skip_regions "${2:-}"; shift ;;
    --skip-region=*) add_skip_regions "${1#*=}" ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
  shift
done

# space-padded so membership checks can match whole region names (bash 3.2 has no associative arrays)
is_skipped() {
  [[ " $SKIP_REGIONS " == *" $1 "* ]]
}

command -v aws >/dev/null 2>&1 || { echo "aws CLI not found in PATH" >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# describe-regions needs a region; fall back to us-east-1 when none is configured
REGIONS=$(aws ec2 describe-regions --region "${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}" \
  --filters Name=opt-in-status,Values=opt-in-not-required,opted-in \
  --query 'Regions[].RegionName' --output text | tr -s '[:space:]' ' ')

for skip in $SKIP_REGIONS; do
  if [[ " $REGIONS " != *" $skip "* ]]; then
    echo "Error: --skip-region $skip is not an enabled region in account ${ACCOUNT_ID}" >&2
    exit 1
  fi
done

echo "Account: ${ACCOUNT_ID}"
if [[ "$EXECUTE" == true ]]; then
  echo "Mode:    EXECUTE (default VPCs will be deleted)"
else
  echo "Mode:    DRY RUN (pass --execute to delete)"
fi
if [[ -n "${SKIP_REGIONS// /}" ]]; then
  echo "Skip:    $(echo $SKIP_REGIONS)"
fi
echo

if [[ "$EXECUTE" == true && "$ASSUME_YES" != true ]]; then
  read -r -p "Delete all default VPCs in account ${ACCOUNT_ID}? Type the account ID to confirm: " reply
  if [[ "$reply" != "$ACCOUNT_ID" ]]; then
    echo "Confirmation did not match. Aborting."
    exit 1
  fi
  echo
fi

run() {
  if [[ "$EXECUTE" == true ]]; then
    "$@"
  else
    echo "    [dry-run] $*"
  fi
}

# Prints a reason and returns 1 if anything besides the default resources would block deleting the VPC.
check_dependencies() {
  local region="$1" vpc_id="$2" count blocked=0

  count=$(aws ec2 describe-network-interfaces --region "$region" \
    --filters Name=vpc-id,Values="$vpc_id" \
    --query 'length(NetworkInterfaces)' --output text) || { echo "    blocked: unable to check dependencies"; return 1; }
  [[ "$count" != "0" ]] && { echo "    blocked: $count network interface(s) in use"; blocked=1; }

  count=$(aws ec2 describe-security-groups --region "$region" \
    --filters Name=vpc-id,Values="$vpc_id" \
    --query "length(SecurityGroups[?GroupName!='default'])" --output text) || { echo "    blocked: unable to check dependencies"; return 1; }
  [[ "$count" != "0" ]] && { echo "    blocked: $count non-default security group(s)"; blocked=1; }

  count=$(aws ec2 describe-route-tables --region "$region" \
    --filters Name=vpc-id,Values="$vpc_id" \
    --query 'length(RouteTables)' --output text) || { echo "    blocked: unable to check dependencies"; return 1; }
  [[ "$count" -gt 1 ]] && { echo "    blocked: $((count - 1)) non-main route table(s)"; blocked=1; }

  count=$(aws ec2 describe-network-acls --region "$region" \
    --filters Name=vpc-id,Values="$vpc_id" \
    --query 'length(NetworkAcls[?IsDefault==`false`])' --output text) || { echo "    blocked: unable to check dependencies"; return 1; }
  [[ "$count" != "0" ]] && { echo "    blocked: $count non-default network ACL(s)"; blocked=1; }

  count=$(aws ec2 describe-vpc-endpoints --region "$region" \
    --filters Name=vpc-id,Values="$vpc_id" \
    --query 'length(VpcEndpoints)' --output text) || { echo "    blocked: unable to check dependencies"; return 1; }
  [[ "$count" != "0" ]] && { echo "    blocked: $count VPC endpoint(s)"; blocked=1; }

  count=$(aws ec2 describe-vpn-gateways --region "$region" \
    --filters Name=attachment.vpc-id,Values="$vpc_id" Name=attachment.state,Values=attached,attaching \
    --query 'length(VpnGateways)' --output text) || { echo "    blocked: unable to check dependencies"; return 1; }
  [[ "$count" != "0" ]] && { echo "    blocked: $count attached VPN gateway(s)"; blocked=1; }

  return "$blocked"
}

# Each step returns early on failure so one bad VPC doesn't stop the remaining regions.
delete_vpc() {
  local region="$1" vpc_id="$2" igw_ids subnet_ids igw_id subnet_id

  igw_ids=$(aws ec2 describe-internet-gateways --region "$region" \
    --filters Name=attachment.vpc-id,Values="$vpc_id" \
    --query 'InternetGateways[].InternetGatewayId' --output text) || return 1
  for igw_id in $igw_ids; do
    echo "    internet gateway: $igw_id"
    run aws ec2 detach-internet-gateway --region "$region" \
      --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" || return 1
    run aws ec2 delete-internet-gateway --region "$region" \
      --internet-gateway-id "$igw_id" || return 1
  done

  subnet_ids=$(aws ec2 describe-subnets --region "$region" \
    --filters Name=vpc-id,Values="$vpc_id" \
    --query 'Subnets[].SubnetId' --output text) || return 1
  for subnet_id in $subnet_ids; do
    echo "    subnet: $subnet_id"
    run aws ec2 delete-subnet --region "$region" --subnet-id "$subnet_id" || return 1
  done

  echo "    vpc: $vpc_id"
  run aws ec2 delete-vpc --region "$region" --vpc-id "$vpc_id" || return 1
}

deleted=0
skipped=0
failed=0

for region in $REGIONS; do
  if is_skipped "$region"; then
    echo "[$region] skipped by --skip-region"
    continue
  fi

  if ! vpc_ids=$(aws ec2 describe-vpcs --region "$region" \
      --filters Name=isDefault,Values=true \
      --query 'Vpcs[].VpcId' --output text 2>/dev/null); then
    echo "[$region] SKIPPING: unable to query region (access denied or region disabled)"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ -z "$vpc_ids" || "$vpc_ids" == "None" ]]; then
    echo "[$region] no default VPC"
    continue
  fi

  for vpc_id in $vpc_ids; do
    echo "[$region] default VPC: $vpc_id"

    if ! check_dependencies "$region" "$vpc_id"; then
      echo "    SKIPPING: VPC is in use or has resources that block deletion"
      skipped=$((skipped + 1))
      continue
    fi

    if delete_vpc "$region" "$vpc_id"; then
      deleted=$((deleted + 1))
    else
      echo "    FAILED: VPC may be partially deleted, check it in the console" >&2
      failed=$((failed + 1))
    fi
  done
done

echo
if [[ "$EXECUTE" == true ]]; then
  echo "Done. Deleted: $deleted, skipped: $skipped, failed: $failed"
else
  echo "Dry run complete. Would delete: $deleted, would skip: $skipped"
fi
[[ "$failed" == "0" ]]
