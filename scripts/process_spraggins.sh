#!/usr/bin/env bash
set -o errexit

. ./scripts/utils.sh

main() {
    # Download and process data which describes an imaging
    # mass spectrometry (IMS) experiment. A single zarr store is created.

    get_CLI_args "$@"

    # IMS data
    IMS_IMZML_IN="$INPUT/spraggins.ims.imzml"
    IMS_IBD_IN="$INPUT/spraggins.ims.ibd"
    IMS_ZARR_OUT="$OUTPUT/spraggins.ims.zarr"
    IMS_JSON_OUT="$OUTPUT/spraggins.ims.image.json"
    IMS_IMAGE_NAME="Spraggins IMS"

    # MXIF data
    MXIF_TIFF_IN="$INPUT/spraggins.mxif.ome.tif"
    MXIF_ZARR_OUT="$OUTPUT/spraggins.mxif.zarr"
    MXIF_JSON_OUT="$OUTPUT/spraggins.mxif.image.json"
    MXIF_IMAGE_NAME="Spraggins MxIF"

    RASTER_JSON="$OUTPUT/spraggins.raster.json"


    # CLOUD SOURCE
    SOURCE_URL="https://vitessce-data.s3.amazonaws.com/source-data/spraggins"

    # CLOUD TARGET
    RELEASE=${CLOUD_TARGET//vitessce-data\//}
    DEST_URL="https://vitessce-data.storage.googleapis.com/$RELEASE/spraggins/"

    echo "Download and process IMS data..."

    [ -e "$IMS_IMZML_IN" ] || \
        wget "$SOURCE_URL/spraggins.ims.imzml" -O "$IMS_IMZML_IN"
    [ -e "$IMS_IBD_IN" ] || \
        wget "$SOURCE_URL/spraggins.ims.ibd" -O "$IMS_IBD_IN"

    if [ -e "$IMS_ZARR_OUT" ]
    then
        echo "Skipping zarr -- output already exists: $IMS_ZARR_OUT"
    else
        echo 'Generating IMS zarr may take a while...'
        CMD="$BASE/python/imzml_reader.py
            --imzml_file $IMS_IMZML_IN
            --ibd_file $IMS_IBD_IN
            --ims_zarr $IMS_ZARR_OUT
            --image_json $IMS_JSON_OUT
            --image_name '$IMS_IMAGE_NAME'
            --dest_url $DEST_URL"
        echo "Running: $CMD"
        eval $CMD
    fi

    if [ -e "$MXIF_ZARR_OUT" ]
    then
        echo "Skipping tiling -- output already exists: $MXIF_ZARR_OUT"
    else
        if [ -e "$MXIF_TIFF_IN" ]
        then
          echo "Not copying $MXIF_TIFF_IN from s3 - already exists or testing"
        else
          wget "$SOURCE_URL/spraggins.ome.tif" -O "$MXIF_TIFF_IN"
        fi
        echo 'Converting OME-TIFF to zarr may take a while...'
        CMD="$BASE/python/ome_tiff_reader.py
            --input_tiff $MXIF_TIFF_IN
            --output_zarr $MXIF_ZARR_OUT
            --image_json $MXIF_JSON_OUT
            --image_name '$MXIF_IMAGE_NAME'
            --dest_url $DEST_URL"
        echo "Running: $CMD"
        eval $CMD
    fi

    CMD="$BASE/python/write_raster_metadata.py
        --raster_json $RASTER_JSON
        --image_metadata_dir $OUTPUT/
        --render_layers '$MXIF_IMAGE_NAME,$IMS_IMAGE_NAME'"
    echo "Running: $CMD"
    eval $CMD

    rm "$OUTPUT/"*.image.json
}

### Main

main "$@"
