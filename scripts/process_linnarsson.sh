#!/usr/bin/env bash
set -o errexit

. ./scripts/utils.sh

main() {
    get_CLI_args "$@"

    process_linnarson_cells
    process_linnarson_molecules
    process_linnarson_images
}

### Globals

BLOBS_URL='https://storage.googleapis.com/linnarsson-lab-www-blobs/blobs'
OSMFISH_URL='http://linnarssonlab.org/osmFISH'

### Functions

process_linnarson_cells() {
    # Download and process data which describes cell locations, boundaries,
    # and gene expression levels. Multiple JSON output files are produced:
    # The files are redudant, but this reduces the processing that needs
    # to be done on the client-side.

    LOOM_IN="$INPUT/linnarsson.cells.loom"
    PKL_IN="$INPUT/linnarsson.cells.pkl"
    JSON_OUT="$OUTPUT/linnarsson.cells.json"

    CLI_ARGS="--integers --loom $LOOM_IN --pkl $PKL_IN"
    add_CLI_ARGS 'cells' 'linnarsson'
    add_CLI_ARGS 'clusters' 'linnarsson'
    add_CLI_ARGS 'genes' 'linnarsson'
    add_CLI_ARGS 'neighborhoods' 'linnarsson'
    add_CLI_ARGS 'factors' 'linnarsson'

    echo "Download and process cells..."

    [ -e "$LOOM_IN" ] || \
        wget "$OSMFISH_URL/osmFISH_SScortex_mouse_all_cells.loom" -O "$LOOM_IN"
    [ -e "$PKL_IN" ] || \
        wget "$BLOBS_URL/osmFISH/data/polyT_seg.pkl" -O "$PKL_IN"

    if [ -e "$JSON_OUT" ]
    then
        echo "Skipping cells -- output already exists: $JSON_OUT"
    else
        echo 'Generating cells JSON may take a while...'
        CMD="$BASE/python/cell_reader.py $CLI_ARGS"
        echo "Running: $CMD"
        eval $CMD
    fi
}

process_linnarson_molecules() {
    # Download and process data which describes molecule locations.
    # In structure, this is the simplest data, but it is also the largest.

    HDF5_IN="$INPUT/linnarsson.molecules.hdf5"
    JSON_OUT="$OUTPUT/linnarsson.molecules.json"

    echo "Download and process molecules..."

    [ -e "$HDF5_IN" ] || \
        wget "$BLOBS_URL/osmFISH/data/mRNA_coords_raw_counting.hdf5" -O "$HDF5_IN"

    if [ -e "$JSON_OUT" ]
    then
        echo "Skipping molecules -- output already exists: $JSON_OUT"
    else
        echo 'Generating molecules JSON may take a while...'
        CMD="$BASE/python/counts_hdf5_reader.py --hdf5 $HDF5_IN > $JSON_OUT"
        echo "Running: $CMD"
        eval $CMD
    fi
}

process_linnarson_images() {
    # Download and process raster data from HDF5 and produce PNGs.
    # Down the road we may want HiGlass, or some other solution:
    # This is a stopgap.

    # NOTE: The name is actually "Linnarsson", with two "S"s, but this is the URL.
    PKLAB_URL='http://pklab.med.harvard.edu/viktor/data/spatial/linnarson'
    HDF5_IN="$INPUT/linnarsson.imagery.hdf5"
    JSON_OUT="$OUTPUT/linnarsson.raster.json"
    ZARR_OUT="$OUTPUT/linnarsson.images.zarr"
    RASTER_NAME="Linnarsson"

    RELEASE=${CLOUD_TARGET//vitessce-data\//}
    DEST_URL="https://vitessce-data.storage.googleapis.com/$RELEASE/linnarsson/"

    if [ -e "$JSON_OUT" ]
    then
        echo "Skipping big image generation -- output already exists: $JSON_OUT"
    else
        echo "Download and generate big images..."

        [ -e "$HDF5_IN" ] || \
            wget "$PKLAB_URL/Nuclei_polyT.int16.sf.hdf5" -O "$HDF5_IN"

        CMD="$BASE/python/img_hdf5_reader.py
            --hdf5 $HDF5_IN
            --zarr_file $ZARR_OUT
            --sample 1
            --channels polyT,nuclei
            --raster_json $JSON_OUT
            --raster_name $RASTER_NAME
            --dest_url $DEST_URL"
        echo "Running: $CMD"
        $CMD
    fi
}

### Main

main "$@"
