#!/usr/bin/env bash

unset PYTORCH_VERSION
# For unittest, nightly PyTorch is used as the following section,
# so no need to set PYTORCH_VERSION.
# In fact, keeping PYTORCH_VERSION forces us to hardcode PyTorch version in config.
apt-get update && apt-get install -y git wget libglew-dev libx11-dev x11proto-dev g++ gcc

set -e

eval "$(./conda/bin/conda shell.bash hook)"
conda activate ./env

#apt-get update -y && apt-get install git wget gcc g++ -y

if [ "${CU_VERSION:-}" == cpu ] ; then
    cudatoolkit="cpuonly"
    version="cpu"
else
    if [[ ${#CU_VERSION} -eq 4 ]]; then
        CUDA_VERSION="${CU_VERSION:2:1}.${CU_VERSION:3:1}"
    elif [[ ${#CU_VERSION} -eq 5 ]]; then
        CUDA_VERSION="${CU_VERSION:2:2}.${CU_VERSION:4:1}"
    fi
    echo "Using CUDA $CUDA_VERSION as determined by CU_VERSION ($CU_VERSION)"
    version="$(python -c "print('.'.join(\"${CUDA_VERSION}\".split('.')[:2]))")"
    cudatoolkit="cudatoolkit=${version}"
fi

case "$(uname -s)" in
    Darwin*) os=MacOSX;;
    *) os=Linux
esac

# submodules
git submodule sync && git submodule update --init --recursive

printf "Installing PyTorch with %s\n" "${CU_VERSION}"
if [ "${CU_VERSION:-}" == cpu ] ; then
    conda install pytorch==2.0 torchvision==0.15 cpuonly -c pytorch -y
else
    conda install pytorch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 pytorch-cuda=11.8 "numpy<2.0" -c pytorch -c nvidia -y
fi

# Solving circular import: https://stackoverflow.com/questions/75501048/how-to-fix-attributeerror-partially-initialized-module-charset-normalizer-has
pip install -U charset-normalizer

# install tensordict
if [[ "$RELEASE" == 0 ]]; then
  pip3 install git+https://github.com/pytorch/tensordict.git
else
  pip3 install tensordict
fi

# smoke test
python -c "import tensordict"

printf "* Installing torchrl\n"
python setup.py develop
python -c "import torchrl"
