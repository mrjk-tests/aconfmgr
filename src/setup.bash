# setup.bash

# This file contains the implementation of aconfmgr's 'setup' command.

function AconfSetup() {
  aconfmgr_action=setup
  aconfmgr_run_mode=setup
  
  # Default import
  AconfSource "$root_dist" lib || true
  AconfSource "$root_dist" setup || true

  # Automagically run the system compliance
  if ! $aconfmgr_applied
  then
    ApplyStates
  fi

}

: # include in coverage

