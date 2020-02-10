#!/usr/bin/env bash
set -o errexit

. ./scripts/utils.sh

main() {

  get_CLI_args "$@"

  TILES_BASE='vanderbilt_MxIF.images'
  TILES_PATH="$OUTPUT/$TILES_BASE"
  if [ -e "$TILES_PATH" ]
  then
      echo "Skipping tiling -- output already exists: $TILES_PATH"
  else
      mkdir $TILES_PATH
      if [ -e "$INPUT/vanderbilt.ome.tif" ]
      then
        echo "Not copying $INPUT/vanderbilt.ome.tif from s3 - already exists or testing"
      else
        aws s3 cp s3://vitessce-data/source-data/vanderbilt_MxIF/vanderbilt.ome.tif "$INPUT/vanderbilt.ome.tif"
      fi
      SERVER_URL="https://vitessce-vanderbilt-data.storage.googleapis.com/"
      CMD='docker run --rm
          -e "SERVER_URL='$SERVER_URL'"
          -e "PREFIX=vanderbilt_MxIF"
          -e "PYRAMID_TYPE=tiff"
          --mount "type=bind,src='$INPUT'/vanderbilt.ome.tif,destination=/input.ome.tif"
          --mount "type=bind,src='$OUTPUT',destination=/output_dir"
          --name tiler gehlenborglab/ome-tiff-tiler:v0.0.4'
      echo "Running: $CMD"
      # vitessce relies on this naming strategy, whereas the docker image is more general
      eval $CMD
      mv "$TILES_PATH/tiff.json" "$TILES_PATH/vanderbilt_MxIF.tiff.json"
  fi
}

main "$@"
