#!/bin/bash
# set -x
START_PAGE_NUMBER=$1
TOTAL_PAGES=$2
LAST_PAGE_NUMBER=$((START_PAGE_NUMBER+TOTAL_PAGES-1))
LEFT_X=4
TOP_Y=194
PAGE_WIDTH=1344
PAGE_HEIGHT=759
LEFT_PAGE_BOX="${LEFT_X},${TOP_Y},${PAGE_WIDTH},${PAGE_HEIGHT}"
RIGHT_PAGE_BOX="583,${TOP_Y},${PAGE_WIDTH},${PAGE_HEIGHT}"
OUTPUT_DIR="$HOME/Slides"
BASENAME="p"
EXT="png"
STATE=0
LEFT_PAGE_CAPTURED=$((0x1))
RIGHT_PAGE_CAPTURED=$((0x2))
LEFT_PAGE_VISIBLE=$((0x4))
RIGHT_PAGE_VISIBLE=$((0x8))

function zoom_in() {
  ZOOM_BTN_X=25
  ZOOM_BTN_Y=1055
  cliclick dd:${ZOOM_BTN_X},${ZOOM_BTN_Y}
  cliclick du:${ZOOM_BTN_X},${ZOOM_BTN_Y}
  sleep 1
}

function move_cursor_off_page() {
  cliclick m:25,175
}

function drag_up() {
  local START_Y=300
  local DY=$1
  local END_Y=$((START_Y-DY))
  cliclick dd:25,$START_Y
  cliclick du:25,$END_Y
}

function log_state() {
  echo "state=0b$(echo "obase=2; $STATE" | bc)"
}

function is_left_page_visible() {
  ((STATE & LEFT_PAGE_VISIBLE))
}

function is_right_page_visible() {
  ((STATE & RIGHT_PAGE_VISIBLE))
}

function is_left_page_captured() {
  ((STATE & LEFT_PAGE_CAPTURED))
}

function is_right_page_captured() {
  ((STATE & RIGHT_PAGE_CAPTURED))
}

function drag_left_page_to_screen() {
  cliclick dd:25,$((TOP_Y+6))
  cliclick du:900,$((TOP_Y+6))
  move_cursor_off_page
  ((STATE |= LEFT_PAGE_VISIBLE))
  ((STATE &= ~RIGHT_PAGE_VISIBLE))
  log_state
  sleep 1
}

function drag_right_page_to_screen() {
  cliclick dd:1500,$((TOP_Y+6))
  cliclick du:100,$((TOP_Y+6))
  move_cursor_off_page
  ((STATE &= ~LEFT_PAGE_VISIBLE))
  ((STATE |= RIGHT_PAGE_VISIBLE))
  log_state
  sleep 1
}

function flip_to_next_page() {
  osascript -e 'tell application "System Events" to key code 124'
  ((STATE &= ~LEFT_PAGE_CAPTURED))
  ((STATE &= ~RIGHT_PAGE_CAPTURED))
  log_state
  sleep 2
}

function check_state_valid() {
  if is_left_page_visible && is_right_page_visible; then
    echo "WARNING: suspicious state - both pages are visible"
  fi
}

function capture_page() {
  local PAGE_N=$1
  local BOX
  check_state_valid
  if is_left_page_visible; then
    BOX=$LEFT_PAGE_BOX
    ((STATE |= LEFT_PAGE_CAPTURED))
  else
    BOX=$RIGHT_PAGE_BOX
    ((STATE |= RIGHT_PAGE_CAPTURED))
  fi
  local FILENAME
  FILENAME="${BASENAME}_$(printf "%03d" "${PAGE_N}").$EXT"
  local FILEPATH="$OUTPUT_DIR/$FILENAME"
  screencapture -R${BOX} "$FILEPATH"
  echo "[$(date)] $FILEPATH"
  log_state
}

function capture() {
  open -a 'Google Chrome'
  sleep 1
  zoom_in
  drag_up 12
  PAGE_N=$START_PAGE_NUMBER
  drag_left_page_to_screen
  while ((PAGE_N <= LAST_PAGE_NUMBER)); do
    capture_page "${PAGE_N}"
    if ((PAGE_N == LAST_PAGE_NUMBER)); then break; fi
    if is_left_page_captured && is_right_page_captured; then
      flip_to_next_page
      ((PAGE_N+=2))
      continue
    fi
    if is_left_page_visible; then
      if is_left_page_captured; then
        drag_right_page_to_screen
        ((PAGE_N++))
      fi
    elif is_right_page_visible; then
      if is_right_page_captured; then
        drag_left_page_to_screen
        ((PAGE_N--))
      fi
    fi
  done
}

img2pdf "$OUTPUT_DIR/${BASENAME}"*.${EXT} -o "$OUTPUT_DIR"/slides.pdf
