#!/usr/bin/env bash

set -e

source ./path.sh
source ./setup.sh

####################################
## Link steps and utils directory ##
####################################
ln -sf $KALDI_ROOT/egs/wsj/s5/steps
ln -sf $KALDI_ROOT/egs/wsj/s5/utils

##############################
## Step 0: Data preparation ##
##############################

########################################
## create data directory for training ##
########################################
local/create_data.py \
    --scp_file $amdtk_exp_dir/$scp \
    --keys_file $amdtk_exp_dir/$keys \
    --labs_dir $amdtk_exp_dir/$labels \
    --data_dir data/train

utils/utt2spk_to_spk2utt.pl \
    data/train/utt2spk \
    > data/train/spk2utt

##########################################
## make features and compute cmvn stats ##
##########################################
steps/make_plp.sh \
    data/train

steps/compute_cmvn_stats.sh \
    data/train

############################################
## create language directory for training ##
############################################
local/create_local_dict.py \
    --text data/train/text \
    --local_dict data/local/dict

oov=$(head -n 1 data/local/dict/lexicon.txt | cut -d ' ' -f 1)

utils/prepare_lang.sh \
    --sil-prob 0 \
    --position-dependent-phones false \
    data/local/dict \
    ${oov} \
    data/local/lang \
    data/lang

#################################################
## Step 1: Train with bigram labels from amdtk ##
##         and estimate vtln wraping factors   ##
#################################################

##################################################################
## run monophone training (plp + delta + delta-delta features) ##
##################################################################
steps/train_mono.sh \
    --cmvn-opts "--norm-vars=true" \
    data/train \
    data/lang \
    exp/mono

steps/align_si.sh \
    data/train \
    data/lang \
    exp/mono \
    exp/mono_ali

########################################################################
## run triphone training (lvtln + plp + delta + delta-delta features) ##
########################################################################
steps/train_lvtln.sh \
    --cmvn-opts "--norm-vars=true" \
    --base-feat-type plp \
    2000 \
    10000 \
    data/train \
    data/lang \
    exp/mono_ali \
    exp/monolvtln

steps/align_lvtln.sh \
    data/train \
    data/lang \
    exp/monolvtln \
    exp/monolvtln_ali

################################################
## Step 2: Do further training of trigram     ##
##         models on vtln wrapped features    ##
##         - plp + vtln + delta + delta-delta ##
##         - plp + vtln + lda + mllt          ##
##         - plp + vtln + fmllr + lda + mllt  ##
################################################

#############################################
## Copy data dir and vtln wrapping factors ##
#############################################
utils/copy_data_dir.sh \
    data/train \
    data/train_vtln

cp exp/monolvtln/final.warp data/train_vtln/spk2warp

##########################################
## make features and compute cmvn stats ##
##########################################
steps/make_plp.sh \
    data/train_vtln

steps/compute_cmvn_stats.sh \
    data/train_vtln

####################################
## convert features to HTK format ##
####################################
local/get_htk_features.sh \
    data/train_vtln \
    exp/monolvtln_ali \
    data/train_vtln_htk

#######################################################################
## run triphone training (plp + vtln + delta + delta-delta features) ##
#######################################################################
steps/train_deltas.sh \
    --cmvn-opts "--norm-vars=true" \
    2000 \
    10000 \
    data/train_vtln \
    data/lang \
    exp/monolvtln_ali \
    exp/tri1

steps/align_si.sh \
    data/train_vtln \
    data/lang \
    exp/tri1 \
    exp/tri1_ali

##############################################################
## run triphone training (plp + vtln + lda + mllt features) ##
##############################################################
steps/train_lda_mllt.sh \
    --cmvn-opts "--norm-vars=true" \
    --dim 20 \
    2000 \
    10000 \
    data/train_vtln \
    data/lang \
    exp/tri1_ali exp/tri2

steps/align_si.sh \
    data/train_vtln \
    data/lang \
    exp/tri2 \
    exp/tri2_ali

######################################################################
## run triphone training (plp + vtln + fmllr + lda + mllt features) ##
######################################################################
steps/train_sat.sh \
    2000 \
    10000 \
    data/train_vtln \
    data/lang \
    exp/tri2_ali \
    exp/tri3

steps/align_fmllr.sh \
    data/train_vtln \
    data/lang \
    exp/tri3 \
    exp/tri3_ali

####################################
## convert features to HTK format ##
####################################
local/get_htk_features.sh \
    data/train_vtln \
    exp/tri3_ali \
    data/train_fmllr_lda
