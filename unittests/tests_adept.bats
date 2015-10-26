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
  optimize_tile_size TILESIZE 'autodetect' 513 513
  result=${TILESIZE}
  [ "$result" -eq 16 ]
}

@test "Slice Image into Tiles" {
  CLEANFILENAME='test'
  FILEEXTENSION='jpg'
  slice_image_to_ram "test.jpg" 32 "$BATS_TMPDIR/"
  TILESARRAY=($(find "$BATS_TMPDIR/" -maxdepth 1 -iregex ".*$CLEANFILENAME.jpe*g"))
  result=${#TILESARRAY[@]}
  [ "$result" -eq 256 ]
  rm -f "$BATS_TMPDIR/.*.jpe*g"
}

@test "Calculate Tile Count for Reassembly" {
  calculate_tile_count TILEROWS 512 32
  result=${TILEROWS}
  [ "$result" -eq 16 ]
}

# NEEDS IMPLEMENTING: optimize_salient_regions_amount
# NEEDS REFACTORING: reassemble_tiles_into_final_image
# NEEDS REFACTORING: estimate_tile_content_complexity_and_compress
# Uses globals ${TILESTORAGEPATH} and ${FILEEXTENSION} etc. Replace with locals.
# Currently has two steps: recompile + recompress. This should be two seperate functions.
