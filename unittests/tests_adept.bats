#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/../adept.sh" >/dev/null 2>/dev/null

@test "Find Tools" {
  run find_tool IDENTIFY_COMMAND identify
  [ $status -eq 0 ]
}

# Make sure that we actually look for tools in other directories than $PATH
@test "Find Tools with path resolving" {
  run find_tool IDENTIFY_COMMAND nonexistingcommand identify
  [ $status -eq 0 ]
}

@test "Validate Input JPEG" {
  validate_image VALIDJPEG "test.jpg"
  result=${VALIDJPEG}
  [ "$result" -eq 1 ]
}

@test "Read Image Dimension" {
  find_image_dimension IMAGEWIDTH "test.jpg" 'w'
  result=${IMAGEWIDTH}
  [ "$result" -eq 512 ]
}

@test "Optimize Tile Size" {
  optimize_tile_size TILESIZE 'autodetect' 512 512
  result=${TILESIZE}
  [ "$result" -eq 32 ]
}

@test "Optimize Black/White Threshold" {
  optimize_bwthreshold BLACKWHITETHRESHOLD "test.jpg" ${BLACKWHITETHRESHOLD}
  result=${BLACKWHITETHRESHOLD}
  [ "$(echo $result '==' 0.333 | bc -l)" -eq 1 ]
}

@test "Slice Image into Tiles" {
  CLEANFILENAME='test'
  FILEEXTENSION='jpg'
  slice_image_to_ram "test.jpg" 32 "$BATS_TMPDIR/"
  TILESARRAY=($(find "$BATS_TMPDIR/" -maxdepth 1 -iregex ".*.jpe*g"))
  result=${#TILESARRAY[@]}
  [ "$result" -eq 256 ]
  rm -f "$BATS_TMPDIR/.*.jpe*g"
}

# NEEDS REFACTORING: estimate_tile_content_complexity_and_compress

@test "Retrieve Black/White Median" {
  FILEEXTENSION='jpg'
  get_black_white_median BWMEDIAN "test.jpg" "$BATS_TMPDIR/" ${BLACKWHITETHRESHOLD}
  result=${BWMEDIAN}
  [ "$(echo $result '==' 2.00775 | bc -l)" -eq 1 ]
  rm -f "$BATS_TMPDIR/.*.jpe*g"
}

@test "Calculate Tile Count for Reassembly" {
  calculate_tile_count_for_reassembly TILEROWS 512 32
  result=${TILEROWS}
  [ "$result" -eq 16 ]
}

# NEEDS REFACTORING: reassemble_tiles_into_final_image
# Uses globals ${TILESTORAGEPATH} and ${FILEEXTENSION} etc. Replace with locals.
# Currently has two steps: recompile + recompress. This should be two seperate functions.
