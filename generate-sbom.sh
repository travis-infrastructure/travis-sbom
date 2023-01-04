#!/bin/bash

# set -x
set -euo pipefail

# CONFIGS
OUTPUT_FORMAT=${1:-'cyclonedx-json'}
OUTPUT_DIR=${2:-'structured_sbom_outputs'}
EXECUTE_PATH=${3:-'/'}

# SBOM
# <<-- GO SBOM
bom_go() {
  echo "Starting sbom generation..........."

  local dir=${1:4}  

  mkdir -p $OUTPUT_DIR$dir

  $(cyclonedx-gomod mod -$OUTPUT_FORMAT_DX -licenses -output $OUTPUT_DIR$dir/golang_bom.$OUTPUT_FORMAT_DX $1)

  if [ "$OUTPUT_FORMAT" == "spdx-json" ]; then
    cyclonedx-cli convert --input-file $OUTPUT_DIR$dir/golang_bom.$OUTPUT_FORMAT_DX --output-format spdxjson --output-file $OUTPUT_DIR$dir/golang_bom_spdx.$OUTPUT_FORMAT_DX
    rm -f $OUTPUT_DIR$dir/golang_bom.$OUTPUT_FORMAT_DX
  fi

  echo "Finished GO sbom generation"
}
# -->>

# <<-- NODE SBOM
bom_node() {
  echo "Starting Node sbom generation..........."

  local dir=${2:4}

  mkdir -p $OUTPUT_DIR$dir

  pushd ${2}
  npm install
  chmod -R 777 node_modules
  popd
  
  cyclonedx-npm --output-file $OUTPUT_DIR$dir/node_bom.$OUTPUT_FORMAT_DX --output-format $OUTPUT_FORMAT_DX ${1}

  if [ "$OUTPUT_FORMAT" == "spdx-json" ]; then
    cyclonedx-cli convert --input-file $OUTPUT_DIR$dir/node_bom.$OUTPUT_FORMAT_DX --output-format spdxjson --output-file $OUTPUT_DIR$dir/node_bom_spdx.$OUTPUT_FORMAT_DX
    rm -f $OUTPUT_DIR$dir/node_bom.$OUTPUT_FORMAT_DX
  fi

  echo "Finished Node sbom generation"
}
# -->>

# <<-- RUBY SBOM
bom_ruby() {
  echo "Starting Ruby sbom generation..........."

  local dir=${1:4}  

  mkdir -p $OUTPUT_DIR$dir

  cyclonedx-ruby -p $1 -f $OUTPUT_FORMAT_DX -o $OUTPUT_DIR$dir/ruby_bom.$OUTPUT_FORMAT_DX

  if [ "$OUTPUT_FORMAT" == "spdx-json" ]; then
    cyclonedx-cli convert --input-file $OUTPUT_DIR$dir/ruby_bom.$OUTPUT_FORMAT_DX --output-format spdxjson --output-file $OUTPUT_DIR$dir/ruby_bom_spdx.$OUTPUT_FORMAT_DX
    rm -f $OUTPUT_DIR$dir/ruby_bom.$OUTPUT_FORMAT_DX
  fi

  echo "Finished Ruby sbom generation"
}
# -->>

# <<-- PYTHON SBOM
bom_python() {
  echo "Starting Python sbom generation..........."

  local dir=${2:4}  

  mkdir -p $OUTPUT_DIR$dir

  cyclonedx-py $3 -i $1 --format $OUTPUT_FORMAT_DX -o $OUTPUT_DIR$dir/python_bom.$OUTPUT_FORMAT_DX

  if [ "$OUTPUT_FORMAT" == "spdx-json" ]; then
    cyclonedx-cli convert --input-file $OUTPUT_DIR$dir/python_bom.$OUTPUT_FORMAT_DX --output-format spdxjson --output-file $OUTPUT_DIR$dir/python_bom_spdx.$OUTPUT_FORMAT_DX
    rm -f $OUTPUT_DIR$dir/python_bom.$OUTPUT_FORMAT_DX
  fi

  echo "Write output to: $OUTPUT_DIR$dir/python_bom.$OUTPUT_FORMAT_DX"

  echo "Finished Python sbom generation"
}
# -->>

# <<-- PHP SBOM
bom_php() {
  # echo "Exection location is ${2}"
  echo "Starting PHP sbom generation..........."

  local dir=${2:4}  

  mkdir -p $OUTPUT_DIR$dir

  composer make-bom --working-dir=$2 --output-format=$OUTPUT_FORMAT_DX --output-file=$OUTPUT_DIR$dir/php_composer_bom.$OUTPUT_FORMAT_DX $1

  if [ "$OUTPUT_FORMAT" == "spdx-json" ]; then
    cyclonedx-cli convert --input-file $OUTPUT_DIR$dir/php_composer_bom.$OUTPUT_FORMAT_DX --output-format spdxjson --output-file $OUTPUT_DIR$dir/php_composer_bom_spdx.$OUTPUT_FORMAT_DX
    rm -f $OUTPUT_DIR$dir/php_composer_bom.$OUTPUT_FORMAT_DX
  fi

  echo "Finished PHP sbom generation"
}
# -->>

# <<-- CPP SBOM
bom_cpp() {
  echo "Starting Conan sbom generation..........."

  local dir=${2:4}  

  mkdir -p $OUTPUT_DIR$dir

  cyclonedx-conan -s compiler.version=11 $1 > /dev/null
  cyclonedx-conan -s compiler.version=11 $1 1> $OUTPUT_DIR$dir/cpp_conan_bom.$OUTPUT_FORMAT_DX

  if [ "$OUTPUT_FORMAT" == "spdx-json" ]; then
    cyclonedx-cli convert --input-file $OUTPUT_DIR$dir/cpp_conan_bom.$OUTPUT_FORMAT_DX --output-format spdxjson --output-file $OUTPUT_DIR$dir/cpp_conan_bom_spdx.$OUTPUT_FORMAT_DX
    rm -f $OUTPUT_DIR$dir/cpp_conan_bom.$OUTPUT_FORMAT_DX
  fi

  echo "Finished Conan sbom generation"
}
# -->>

# <<-- JAVA SBOM
bom_java() {
  echo "Starting Java sbom generation..........."

  local dir=${1:4}  

  mkdir -p $OUTPUT_DIR$dir

  syft $1 --catalogers java -o $OUTPUT_FORMAT=$OUTPUT_DIR$dir/java_bom.$OUTPUT_FORMAT_DX

  echo "Finished Java sbom generation"
}
# -->>

heartbeat() {
  while true
  do
    echo "[$(date)] SBOM in progress"
    sleep 600
  done
}

## Main Exection
execute() {
  pwd
  if [[ -z $EXECUTE_PATH ]]; then
    echo "no path provided"
    exit 0
  fi

  case ${OUTPUT_FORMAT} in
    "cyclonedx-json") readonly OUTPUT_FORMAT_DX="json"
    ;;
    "cyclonedx-xml") readonly OUTPUT_FORMAT_DX="xml"
    ;;
    "spdx-json") readonly OUTPUT_FORMAT_DX="json"
    ;;
  esac

  echo "Scanning source code..."

  readarray -td, a < <(printf '%s' "$EXECUTE_PATH"); declare -p a >/dev/null;

  mkdir -p raw_tool_outputs

  heartbeat &

  for i in "${a[@]}"; do
    echo "Scanning input directory $i"

    for file in `find /app${i} -maxdepth 1 -type f \( -iname "package-lock.json" -o -iname "go.mod" -o -iname "Gemfile.lock" -o -iname "Pipfile.lock" -o -iname "poetry.lock" -o -iname "requirements.txt" -o -iname "composer.json" -o -iname "conanfile.txt" -o -iname "pom.xml" -o -iname "build.gradle" \)`; do
      local dir=$(dirname "$file")

      case ${file} in
        *"/Gemfile.lock") echo "Searching gemfile..." && bom_ruby $dir
        ;;
        *"/go.mod") echo "Searching go files..." && bom_go $dir
        ;;
        *"/package-lock.json") echo "Searching node package files..." && bom_node $file $dir
        ;;
        *"/Pipfile.lock") echo "Searching python package files..." && bom_python $file $dir "-pip"
        ;;
        *"/poetry.lock") echo "Searching python package files..." && bom_python $file $dir "-p"
        ;;
        *"/requirements.txt") echo "Searching python package files..." && bom_python $file $dir "-r"
        ;;
        *"/composer.json") echo "Searching composer package files..." && bom_php $file $dir
        ;;
        *"/conanfile.txt") echo "Searching conan package files..." && bom_cpp $file $dir
        ;;
        *"/pom.xml" | *"/build.gradle") echo "Searching java package files..." && bom_java $dir
        ;;
      esac
    done;
  done;
  echo "Successfully generated sbom files"

  kill `jobs -p`

  #fle integrity stamping
  echo "Creating SHA256 Checksum.........."
  `find $OUTPUT_DIR/ ! -name '*sha256sums.txt' -type f -exec sha256sum {} > $OUTPUT_DIR/sha256sums.txt \;`
  echo "Successfully Created SHA256 Checksum........."
}

execute
