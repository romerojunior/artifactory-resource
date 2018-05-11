
# Using jq regex so we can support groups
applyRegex_version() {
  local regex=$1
  local file=$2

  jq -n "{
  version: $(echo $file | jq -R .)
  }" | jq --arg v "$regex" '.version | capture($v)' | jq -r '.version'
}

get_current_version() {
  local version_schema=$1
  local regex=$2
  # regex: myapp-(?<version>.*).txt
  local folder_contents=$3

  case $version_schema in
    semver)
        echo "$folder_contents" | jq --arg v "$regex" '[.children[].uri | capture($v)]' | jq 'sort_by(.version | split(".") | map(tonumber))' | jq '[.[length-1] | {version: .version}]'
        ;;
    erv)
        ## do something here
        echo "$folder_contents" | jq --arg v "$regex" '[.children[].uri | capture($v)]' | jq 'sort_by(.version | split(":") | join("") | split("-") | map(tonumber))' | jq '[.[length-1] | {version: .version}]'
        ;;
    *)
        echo "Invalid option"
    ;;
  esac
}

# Return all versions
get_all_versions() {
  local version_schema=$1
  local regex=$2
  local folder_contents=$3

  case $version_schema in
    semver)
        echo "$folder_contents" | jq --arg v "$regex" '[.children[].uri | capture($v)]' | jq 'sort_by(.version | split(".") | map(tonumber))' | jq '[.[] | {version: .version}]'
        ;;
    erv)
        echo "$folder_contents" | jq --arg v "$regex" '[.children[].uri | capture($v)]' | jq 'sort_by(.version | split(":") | join("") | split("-") | map(tonumber))' | jq '[.[] | {version: .version}]'
        ;;
    *)
        echo "Invalid option"
    ;;
  esac
}

get_files() {
  local version_schema=$1
  local regex="(?<uri>$2)"
  local folder_contents=$3


  case $version_schema in
    semver)
        echo "$folder_contents" | jq --arg v "$regex" '[.children[].uri | capture($v)]' | jq 'sort_by(.version  | split(".") | map(tonumber))' | jq '[.[] | {uri: .uri, version: .version}]'
        ;;
    erv)
        echo "$folder_contents" | jq --arg v "$regex" '[.children[].uri | capture($v)]' | jq 'sort_by(.version  | split(":") | join("") | split("-") | map(tonumber))' | jq '[.[] | {uri: .uri, version: .version}]'
        ;;
    *)
        echo "Invalid option"
    ;;
  esac

}

artifactory_get_folder_contents() {
  local artifacts_url=$1
  curl $1
}

# retrieve current from artifactory
# e.g url=http://your-host-goes-here:8081/artifactory/api/storage/your-path-goes-here
#     regex=ecd-front-(?<version>.*).tar.gz
artifactory_current_version() {
  local artifacts_url=$1
  local version_schema=$2
  local regex=$3

  local folder_contents=$(artifactory_get_folder_contents "$1")

  get_current_version "$version_schema" "$regex" "$folder_contents"

}


# Return all versions
artifactory_versions() {
  local artifacts_url=$1
  local version_schema=$2
  local regex=$3

  local folder_contents=$(artifactory_get_folder_contents "$1")

  get_all_versions "$version_schema" "$regex" "$folder_contents"

}

# return uri and version of all files
artifactory_files() {
  local artifacts_url=$1
  local version_schema=$2
  local regex=$3

  local folder_contents=$(artifactory_get_folder_contents "$1")

  get_files "$version_schema" "$regex" "$folder_contents"

}

in_file_with_version() {
  local artifacts_url=$1
  local version_schema=$2
  local regex="(?<uri>$3)"
  local version=$4

  result=$(artifactory_files "$artifacts_url" "$version_schema" "$regex")
  echo $result | jq --arg v "$version" '[foreach .[] as $item ([]; $item ; if $item.version == $v then $item else empty end)]'

}


# return the list of versions from provided version
check_version() {
  local artifacts_url=$1
  local version_schema=$2
  local regex=$3
  local version=$3

  result=$(artifactory_versions "$artifacts_url" "$version_schema" "$regex")
  echo $result | jq --arg v "$version" '[foreach .[] as $item ([]; $item ; if $item.version >= $v then $item else empty end)]'

}
