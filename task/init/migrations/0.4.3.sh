#!/usr/bin/env bash

set -euo pipefail

# Created for task: init@0.4.3
# Creation time: 2026-07-11T05:53:49+00:00

declare -r pipeline_file=${1:?missing pipeline file}

# Add the opt-in reproducibility parameters (source-date-epoch,
# rewrite-timestamp, omit-history) at pipeline level and wire them into the
# buildah build task, mirroring
# https://github.com/konflux-ci/build-definitions/pull/3670 for pipelines
# already copied into user repos. All three default to off, so migrated
# pipelines behave exactly as before.

buildah_task_refs=(
    "buildah" "buildah-oci-ta" "buildah-oci-ta-min"
    "buildah-remote" "buildah-remote-oci-ta"
)

kind=$(yq '.kind' "$pipeline_file")
case "$kind" in
    Pipeline)
        tasks_selector=".spec.tasks[]"
        params_selector=".spec.params"
        params_pmt_path='["spec", "params"]'
        ;;
    PipelineRun)
        tasks_selector=".spec.pipelineSpec.tasks[]"
        params_selector=".spec.pipelineSpec.params"
        params_pmt_path='["spec", "pipelineSpec", "params"]'
        ;;
    *)
        echo "Not a Pipeline or PipelineRun, skipping migration"
        exit 0
        ;;
esac

all_build_tasks=()
for task_refname in "${buildah_task_refs[@]}"; do
    task_filter="${tasks_selector} | select(.taskRef.params[] | (.name == \"name\" and .value == \"${task_refname}\"))"
    if yq -e "$task_filter" "$pipeline_file" >/dev/null 2>&1; then
        readarray -t -O ${#all_build_tasks[@]} all_build_tasks < <(yq -e "${task_filter} | .name" "$pipeline_file")
    fi
done

if [ ${#all_build_tasks[@]} -eq 0 ]; then
    echo "No buildah build tasks found, skipping migration"
    exit 0
fi

if ! yq -e "$params_selector" "$pipeline_file" >/dev/null 2>&1; then
    echo "No ${params_selector} list found, skipping migration"
    exit 0
fi

# Pipeline-level parameter definitions, matching the ones added to the shared
# pipelines by https://github.com/konflux-ci/build-definitions/pull/3670.
# The three arrays are parallel: pipeline param name, task param name, and the
# pipeline-level definition to insert.
pipeline_params=("source-date-epoch" "rewrite-timestamp" "omit-history")
task_params=("SOURCE_DATE_EPOCH" "REWRITE_TIMESTAMP" "OMIT_HISTORY")
param_defs=(
    '{"name": "source-date-epoch", "type": "string", "default": "", "description": "Sets the image created time and the SOURCE_DATE_EPOCH build argument. On its own, it does not change file timestamps inside the layers (set rewrite-timestamp to \"true\" for that). Leave empty to keep the actual build time."}'
    '{"name": "rewrite-timestamp", "type": "string", "default": "false", "description": "When \"true\", clamp file modification times in the image layers to at most source-date-epoch. Does nothing unless source-date-epoch is set."}'
    '{"name": "omit-history", "type": "string", "default": "false", "description": "When \"true\", omit the build history (history timestamps, layer metadata, etc.) from the resulting image."}'
)

# For each parameter: find the build tasks that do not set the task param yet.
# A task param that already exists is left alone so an explicit value set by
# the user is preserved (pmt add-param would replace it). The pipeline-level
# definition is only added when at least one task actually gets the wiring,
# so the migration never adds a param nothing consumes.
for i in 0 1 2; do
    pipeline_param=${pipeline_params[$i]}
    task_param=${task_params[$i]}
    param_def=${param_defs[$i]}

    tasks_to_wire=()
    for task_name in "${all_build_tasks[@]}"; do
        [[ -z "$task_name" ]] && continue
        existing_filter="(${tasks_selector} | select(.name == \"${task_name}\")).params[] | select(.name == \"${task_param}\")"
        if yq -e "$existing_filter" "$pipeline_file" >/dev/null 2>&1; then
            echo "Task ${task_name} already sets ${task_param}, leaving it as is"
        else
            tasks_to_wire+=("$task_name")
        fi
    done

    if [ ${#tasks_to_wire[@]} -eq 0 ]; then
        echo "No build task needs ${task_param}, skipping the ${pipeline_param} parameter"
        continue
    fi

    if yq -e "${params_selector}[] | select(.name == \"${pipeline_param}\")" "$pipeline_file" >/dev/null 2>&1; then
        echo "Parameter ${pipeline_param} already defined, not adding it"
    else
        echo "Adding ${pipeline_param} parameter to ${params_selector}"
        pmt modify -f "$pipeline_file" generic insert "$params_pmt_path" "$param_def"
    fi

    for task_name in "${tasks_to_wire[@]}"; do
        echo "Wiring ${task_param} on task ${task_name} to \$(params.${pipeline_param})"
        # shellcheck disable=SC2016
        pmt modify -f "$pipeline_file" task "${task_name}" add-param "$task_param" "\$(params.${pipeline_param})"
    done
done
