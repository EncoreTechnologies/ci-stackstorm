# ci-stackstorm
Continuous Integration Pipeline for StackStorm packs

## Quick Start

To add testing capabilities to your StackStorm pack simply:

``` shell
git clone https://github.com/EncoreTechnologies/ci-stackstorm.git
cp ci-stackstorm/pack/Makefile /path/to/my/stackstorm/pack/
cd /path/to/my/stackstorm/pack/
make
```

## Details

This repo provides testing in the form of a Makefile.

The Makefile does all of the following when you run the `make` command:

* Cloning this repo into the `ci/` folder within your pack
* Creating a virtualenv in `ci/virtualenv` (note: `virtualenv` must be installed)
* The virtualenv automatically installs all modules in `requirements.txt`, `requirements-dev.txt`, and `requirements-pack-tests.txt`.
* Clones the StackStorm repo into `/tmp/st2`
* Executes commands from the StackStorm repo to validate YAML and JSON files along with execute unit tests


## Tips/Tricks

To get a list of available `make` targets run: `make list`

To clean up all of the data used by this CI system, simply run `make clean`

