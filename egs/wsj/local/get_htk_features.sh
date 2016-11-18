#!/bin/bash

# Begin configuration section.
cmd=run.pl
cmvn_opts=
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh
. parse_options.sh || exit 1;

if [ $# != 3 ]; then
  echo "Usage: $0 <data-in> <exp-dir> <data-out>"
  echo " e.g.: $0 data/train exp/tri3 data/train_fmllr_lda_mllr"
  echo "Main options (for others, see top of script file)"
  exit 1;
fi

data_in=$1
exp_dir=$2
data_out=$3

for f in $data_in/feats.scp; do
  [ ! -f $f ] && echo "$(filename $0): no such file $f" && exit 1;
done

nj=`cat $exp_dir/num_jobs` || exit 1;
sdata=$data_in/split$nj;
splice_opts=`cat $exp_dir/splice_opts 2>/dev/null` # frame-splicing options.
[ -z $cmvn_opts ] && cmvn_opts=`cat $exp_dir/cmvn_opts 2>/dev/null`
delta_opts=`cat $exp_dir/delta_opts 2>/dev/null`

mkdir -p $data_out/log

[[ -d $sdata && $data_in/feats.scp -ot $sdata ]] || split_data.sh $data_in $nj || exit 1;

# Set up features.

if [ -f $exp_dir/final.mat ]; then feat_type=lda; else feat_type=delta; fi
echo "$0: feature type is $feat_type"

## Set up speaker-independent features.
case $feat_type in
  delta) sifeats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | add-deltas $delta_opts ark:- ark:- |";;
  lda) sifeats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | splice-feats $splice_opts ark:- ark:- | transform-feats $exp_dir/final.mat ark:- ark:- |"
    ;;
  *) echo "$0: invalid feature type $feat_type" && exit 1;
esac

## Get initial fMLLR transforms (possibly from alignment dir)
if [ -f $exp_dir/trans.1 ]; then
  echo "$0: Using transforms from $exp_dir"
  feats="$sifeats transform-feats --utt2spk=ark:$sdata/JOB/utt2spk ark,s,cs:$exp_dir/trans.JOB ark:- ark:- |"
else
  feats=$sifeats
fi

# extract features
echo "$0: Extracting HTK features"
$cmd JOB=1:$nj $data_out/log/copy_feats.JOB.log \
  copy-feats-to-htk --output-dir=$data_out --output-ext=fea "$feats" || exit 1;
echo "$0: done extracting HTK featurs to $data_out"

exit 0

