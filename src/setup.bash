# setup.bash

# This file contains the implementation of aconfmgr's 'setup' command.

function AconfSetup() {
  aconfmgr_action=setup
  aconfmgr_run_mode=setup
  
  # Default import
  AconfSourcePath "$config_dir" setup || true

  # Automagically run the system compliance
  if ! [[ ":$config_dir:" =~ :$aconfmgr_applied: ]] ; then
    ApplyStates
  fi

}

: # include in coverage

