# Put the PREFIRE_AUX_SAT sibling packages on PYTHONPATH (the PYTHONPATH method in PREFIRE_AUX_SAT/README.md)
# and keep Python from rewriting tracked bytecode in the submodules.
# Usage, from anywhere: source /path/to/prefire-aux-sat-bundle/bundle_env.sh
_bundle_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PYTHONPATH="${_bundle_root}/PREFIRE_AUX_MET/source:${_bundle_root}/PREFIRE_PRD_GEN/source:${_bundle_root}/PREFIRE_tools/source/python${PYTHONPATH:+:${PYTHONPATH}}"
# PREFIRE_tools tracks three .pyc files; without this, importing it rewrites them and the product provenance says "(modified)"
export PYTHONDONTWRITEBYTECODE=1
unset _bundle_root
