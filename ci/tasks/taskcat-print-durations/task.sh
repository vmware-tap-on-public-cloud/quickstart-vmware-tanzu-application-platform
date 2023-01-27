#!/usr/bin/env bash

set -e
set -u
set -o pipefail

readonly -a PHASES=(
  PhaseCloudInit
  PhaseTAPInstall
  PhaseTAPWorkloadInstall
  PhaseTAPTests
)

REGION="$( cat test-result/region )"
STACK_NAME="$( cat test-result/stackName )"
readonly STACK_NAME REGION

main() {
  local phase
  local -a phaseTimes
  local start end
  local durations='{}'

  local logFile="test-result/${STACK_NAME}-${REGION}-cfnlogs.txt"

  for phase in "${PHASES[@]}" ; do
    # collect all event logs' times, sort them and push them into an array
    # log lines look something like that:
    # ```
    #   [...]
    # 2023-01-30 12:39:41.514000+00:00  CREATE_COMPLETE     AWS::CloudFormation::WaitCondition        WaitForTAPTests
    # 2023-01-30 12:39:41.033000+00:00  CREATE_IN_PROGRESS  AWS::CloudFormation::WaitCondition        WaitForTAPTests                                   Resource creation Initiated
    # 2023-01-30 12:39:40.786000+00:00  CREATE_IN_PROGRESS  AWS::CloudFormation::WaitCondition        WaitForTAPTests
    #   [...]
    # ```
    mapfile -t phaseTimes < <(
      awk -v phase="${phase}" '$5 == phase { print $1 " " $2 }' "$logFile" \
        | sort
    )

    # convert from datetime to epoch seconds
    start="$( date -d "${phaseTimes[0]}" '+%s' )"
    end="$( date -d "${phaseTimes[-1]}" '+%s' )"

    # add the duration, in minutes, to the durations object
    durations="$(
      <<< "$durations" \
      jq \
        --argjson pStart "${start}" \
        --argjson pEnd "${end}" \
        --arg phase "${phase}" \
        '. + { "\($phase)" : ((($pEnd - $pStart)/60)*100 | round / 100) }'
    )"
  done

  # For now, we only print the durations of the different phases. We could also
  # push them out somewhere if we wanted to.
  echo >&2 '# Durations in minutes:'
  jq . <<< "$durations"
}

main "$@"
