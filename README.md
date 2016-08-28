# aconfmgr: A configuration manager for Arch Linux

`aconfmgr` is a tool to track, manage, and restore the configuration of an Arch Linux system.
Its goals are:

- Quickly configure a new system, or restore an existing system according to a saved configuration
- Track temporary/undesired changes to the system's configuration
- Identify obsolete packages and maintain a lean system

`aconfmgr` tracks the list of installed packages (both native and external [TODO]), as well as changes to configuration files (`/etc/` [TODO]).
Since the system configuration is described as shell scripts, it is trivially extensible.

## Modus operandi

This package consists of two scripts:

- `aconf-save` saves the difference between current system's configuration and the configuration described by the `config` directory back to the `config` directory.
- `aconf-apply` applies the difference between the configuration described by the `config` directory and the current system's configuration, installing/removing packages and creating/editing configuration files.

The `config` directory contains shell scripts, initially generated by `aconf-save` and then usually edited by the user. Evaluating these scripts will *compile* a system configuration description in the `output` directory. The difference between that directory's contents, and the actual current system configuration, dictates the actions ultimately taken by `aconf-save` and `aconf-apply`.

`aconf-save` will write the difference to the file `config/99-unsorted.sh` as a series of shell commands which attempt to bring the configuration up to date with the current system. When starting with an empty configuration, this difference will consist of the entire system description. Since the script only appends to that file, it may end up undoing configuration changes done earlier in the scripts (e.g. removing packages from the package list). It is up to the user to refactor the configuration to remove redundancies, document changes, and improve maintainability.

`aconf-apply` will apply the differences to the actual system.

The contracts of both commands are that after a successful invocation of either, invoking either command immediately after will be a no-op.

## Usage

### 1. First run

Run `aconf-save` to transcribe the system's configuration to the `config` directory.

This will create the file `config/99-unsorted.sh`, as well as other files [TODO] describing the system configuration. You should review the contents of `99-unsorted.sh`, and sort it into one or more new files (e.g.: `10-base.sh`, `20-drivers.sh`, `30-gui.sh`, `50-misc.sh` ...). The files should have a `.sh` extension, and use `zsh` syntax. I suggest adding a comment for each package describing why installing the package was needed, so it is clear when the package is no longer needed and can be removed.

During this process, you may identify packages or system changes which are no longer needed. Do not sort them into your configuration files - instead, delete the file `99-unsorted.sh`, and run `aconf-apply`. This will synchronize the system state against your configuration, thus removing the omitted packages. (`pacman` will display a prompt allowing you to review the exact list of packages being removed.)

### 2. Maintenance

The `config` directory should be versioned using a version control system (e.g. Git). Ideally, the file `99-unsorted.sh` should not be versioned - it will only be created when the current configuration does not reflect the current system state.

Periodic maintenance consists of running `aconf-save`; if this results in uncommitted changes to the `config` directory, then there are unaccounted system changes. The changes should be reviewed, sorted, documented, committed and pushed.

### 3. Restoring

To restore a system to its earlier state, or to set up a new system, simply make sure the correct configuration is in the `config` directory and run `aconf-apply`. You will be able to preview and confirm any actual system changes.

### 4. Managing multiple systems

You can use the same `config` repository to manage multiple sufficiently-similar systems. One way of doing so is e.g. Git branches (having one main branch plus one branch per machine, and periodically merge in changes from the main branch into the machine-specific branches); however, it is simpler to use shell scripting:

```bash
packages+=coreutils
# ... more common packages ...

if [[ "$HOST" == "home.example.com" ]]
then
	packages+=nvidia
	packages+=nvidia-utils
	# ... more packages only for the home system ...
fi
```
