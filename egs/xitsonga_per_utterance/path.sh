export KALDI_ROOT=/scratch/owb/Downloads/kaldi
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PATH
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C
