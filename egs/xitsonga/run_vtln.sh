#!/usr/bin/env bash

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
    --write_segments \
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
    --cmvn-opts="--norm-vars=true"
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
