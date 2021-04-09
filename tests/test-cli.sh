#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# Test Directory
d=$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)

test::cli() {
  local dagger="$1"

  test::cli::list "$dagger"
  test::cli::newdir "$dagger"
  test::cli::newgit "$dagger"
  test::cli::query "$dagger"
  test::cli::plan "$dagger"
  test::cli::input "$dagger"
}

test::cli::list() {
  local dagger="$1"

  # Create temporary store
  local DAGGER_STORE
  DAGGER_STORE="$(mktemp -d -t dagger-store-XXXXXX)"
  export DAGGER_STORE

  test::one "CLI: list: no deployments" --stdout="" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" list

  test::one "CLI: list: create deployment" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" new --plan-dir "$d"/cli/simple simple

  test::one "CLI: list: with deployments" --stdout="simple" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" list
}

test::cli::newdir() {
  local dagger="$1"

  # Create temporary store
  local DAGGER_STORE
  DAGGER_STORE="$(mktemp -d -t dagger-store-XXXXXX)"
  export DAGGER_STORE

  test::one "CLI: new: --plan-dir" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" new --plan-dir "$d"/cli/simple simple

  test::one "CLI: new: duplicate name" --exit=1 \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" new --plan-dir "$d"/cli/simple simple

  test::one "CLI: new: verify plan can be upped" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" up -d "simple"

  test::one "CLI: new: verify we have the right plan" --stdout='{
  "bar": "another value",
  "computed": "test",
  "foo": "value"
}' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -f cue -d "simple" -c -f json
}

test::cli::newgit() {
  local dagger="$1"

  # Create temporary store
  local DAGGER_STORE
  DAGGER_STORE="$(mktemp -d -t dagger-store-XXXXXX)"
  export DAGGER_STORE

  test::one "CLI: new git: --plan-git" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" new --plan-git https://github.com/samalba/dagger-test.git simple

  test::one "CLI: new git: verify plan can be upped" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" up -d "simple"

  test::one "CLI: new git: verify we have the right plan" --stdout='{
    foo: "value"
    bar: "another value"
}' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -f cue -d "simple" -c
}

test::cli::query() {
  local dagger="$1"

  # Create temporary store
  local DAGGER_STORE
  DAGGER_STORE="$(mktemp -d -t dagger-store-XXXXXX)"
  export DAGGER_STORE

  test::one "CLI: query: initialize simple" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" new --plan-dir "$d"/cli/simple simple

  test::one "CLI: query: before up" --stdout='{
  "bar": "another value",
  "foo": "value"
}' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "simple"

  test::one "CLI: query: concrete should fail" --exit=1 \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "simple" -c

  test::one "CLI: query: target" --stdout='"value"' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "simple" foo

  test::one "CLI: query: compute missing values" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" up -d "simple"

  test::one "CLI: query: all values" --stdout='{
  "bar": "another value",
  "computed": "test",
  "foo": "value"
}' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "simple"

  test::one "CLI: query: concrete should work" --stdout='{
  "bar": "another value",
  "computed": "test",
  "foo": "value"
}' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "simple" -c

  test::one "CLI: query --no-computed" --stdout='{
  "bar": "another value",
  "foo": "value"
}' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "simple" --no-computed

  test::one "CLI: query: --no-plan" --stdout='{
  "computed": "test"
}' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "simple" -c --no-plan
}

test::cli::plan() {
  local dagger="$1"

  # Create temporary store
  local DAGGER_STORE
  DAGGER_STORE="$(mktemp -d -t dagger-store-XXXXXX)"
  export DAGGER_STORE

  test::one "CLI: new" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" new --plan-dir "$d"/cli/simple simple

  test::one "CLI: plan dir" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" -d "simple" plan dir "$d"/cli/simple

  test::one "CLI: plan dir: verify we have the right plan" --stdout='{
  "bar": "another value",
  "foo": "value"
}' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" -d "simple" query

  test::one "CLI: plan git" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" -d "simple" plan git https://github.com/samalba/dagger-test.git

  test::one "CLI: plan git: verify we have the right plan" --stdout='{
  "bar": "another value",
  "foo": "value"
}' \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "simple" -c
}

test::cli::input() {
  local dagger="$1"

  # Create temporary store
  local DAGGER_STORE
  DAGGER_STORE="$(mktemp -d -t dagger-store-XXXXXX)"
  export DAGGER_STORE

  test::one "CLI: input: new" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" new --plan-dir "$d"/cli/input "input"

  test::one "CLI: input: up missing input" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" up -d "input"

  test::one "CLI: input: query missing input" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "input" --stdout='{
  "foo": "bar"
}'

  test::one "CLI: input: set dir" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" input -d "input" dir "source" ./tests/cli/input/testdata

  test::one "CLI: input: up with input dir" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" up -d "input"

  test::one "CLI: input: query with input dir" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "input" --stdout='{
  "bar": "thisisatest\n",
  "foo": "bar",
  "source": {}
}'

  test::one "CLI: input: set git" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" input -d "input" git "source" https://github.com/samalba/dagger-test-simple.git

  test::one "CLI: input: up with input git" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" up -d "input"

  test::one "CLI: query with input git" \
      "$dagger" "${DAGGER_BINARY_ARGS[@]}" query -d "input" --stdout='{
  "bar": "testgit\n",
  "foo": "bar",
  "source": {}
}'
}