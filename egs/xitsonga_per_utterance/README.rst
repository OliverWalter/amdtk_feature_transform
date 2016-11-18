Simple Kaldi training
=====================
This document is supposed to give a simple overview about how to train models
for speech recognition with Kaldi. For more details check
http://kaldi-asr.org/doc/data_prep.html. In the following, all the mentioned
subdirectories should be created in one base directory, similar to the examples
in the ``egs/*/s5`` directories of your kaldi installation.

The base directory should contain links to the ``wsj/s5/steps`` and
``wsj/s5/utils`` directories in the ``egs`` directory of your kaldi
installation. They should be named ``steps`` and ``utils`` respectively.

The base directory also has to contain the file ``path.sh`` to setup the paths
to the kaldi, openfst and additional tools directories. The file needs to
include at least the following::

  export KALDI_ROOT=<path to your kaldi installation>
  [ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
  export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PATH
  . $KALDI_ROOT/tools/config/common_path.sh
  export LC_ALL=C

Replace ``<path to your kaldi installation>`` with the path to your kaldi
installation. See
http://ntjenkins.upb.de/view/PythonToolbox/job/python_doc/Toolbox_documentation/toolbox_source/tutorial/kaldi.html
for installation instructions.
  
Data preparation
++++++++++++++++
First a data directory has to be prepared, containing the training or testing
data to be processed. Usually the directories should be named ``data/train`` or
``data/test`` repectively. These directories have to contain the following
files.

text
----
The file ``text`` contains the transcriptions of each utterance, one utterance
per line. The transcription is given in words, delimited by spaces. The format
is::

  <utterance-id> <transcription>

wav.scp
-------
The file ``wav.scp`` contains a list of available audio recordings, indentified
by a recording id and followed by the extended filename. In the simple case, the
recording id is equal to the utterance id in the ``text`` file and the extended
filename is the path to the corresponding ``wav`` file.

In the extended case, a ``segments`` file specifies the begin and end times of
utterances in a recording. The extended filename can consist of a command
outputting audio in ``wav`` format to the standard output, followed by a pipe
``|`` symbol. The format of the ``wav.scp`` is::

  <recording-id> <extended-filename>

(optional) segments
-------------------
The file ``segments`` is optional and only needs to be crated if start and end
times are used to specify utterances within a recording. The start and end
times are in seconds. If no segments file is created, the recording ids in the
``wav.scp`` have to match the utterance ids in the ``text`` file. The format of
the ``segments`` file is::

  <utterance-id> <recording-id> <segment-begin> <segment-end>

utt2spk
-------
The file ``utt2spk`` says, for each utterance, which speaker spoke it. In case
no speaker ids are known, but multiple speakers are present, the speaker id
should match the utterance id. If there is a single speaker per recording, 
the speaker id could match the recording id or the utterance id. The format is::

  <utterance-id> <speaker-id>

spk2utt
-------
The file ``spk2utt`` says, for each speaker, which utterances were spoken by
him. The file is created calling the command::

  utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt

feats.scp
---------
The file ``feats.scp`` contains a list of features for all available audio
recordings. The features are extracted to ``data/train/data`` and the
``feats.scp`` created by calling::

  steps/make_mfcc.sh data/train

The file ``conf/mfcc.conf`` has to present, but can be empty when using default
parameters. For possible parameters check ``compute-mfcc-feats --help``.

Alternatively ``fbank`` and ``plp`` features can be extracted by replacing
``mfcc`` with the corresponding feature type. Additionally ``pitch`` features
can be added. For the corresponding scripts, check the ``steps`` directory.

cmvn.scp
--------
The file ``cmvn.scp`` contains statistics for the (cepstral) mean and variance
normalization. The statistics are used to normalize each feature vector
dimension to a mean of zero and a variance of one, on the fly, in further
processing steps. The feature files are unchanged on no new set of feature files
is created. The statistics extracted to ``data/train/data`` and the ``cmvn.scp``
created by calling::

  steps/compute_cmvn_stats.sh data/train

Language directory
++++++++++++++++++
Next a language directory has to be created, containing language specific
information. These information mainly consist of the lexicon, mapping words to
phoneme or character sequences and information about the used phoneme or
character set. The language directory is usually named ``data/lang`` for
training. The directory is created from a directory usually named
``data/local/dict`` containing the following following files.

lexicon.txt
-----------
The file ``lexicon.txt`` contains the mapping from words to phoneme or character
sequences. Each line contains one mapping. If a word has multiple mappings
(pronunciations), multiple lines have to be added for the word. The format is::

  <word> <phone1> <phone2> ...
  
Alternatively the file ``lexiconp.txt`` can be created with the second field,
the field after the word, containing the pronunnciation probability. The format
then is::

  <word> <pronunciation-probability> <phone1> <phone2> ...

nonsilence_phones.txt
---------------------
The file ``nonsilence_phones.txt`` contains a list of actual phonemes or
characters, one phoneme or character per line. In general these are the phonemes
or characters carrying linguistic information.

In addition, multiple units per line can be specified making the following units
aliases of the fist unit. This is uaully used to group differently stressed
versions of the same phoneme together.

silence_phones.txt
------------------
The file ``silence_phones.txt`` contains a list of non linguistic units, one
unit per line. In general there are silence and noise units which contain no
linguistic information. This often also includes spoken noise.

optional_silence.txt
--------------------
The file ``optional_silence.txt`` contains one optional silence unit wich will 
optionally be hypothesized at the beginning of each utterance and after each
word. The probability of this unit is controlled by the option ``--sil-prob``
when creating the ``data/lang`` directory. If the option ``--sil-prob`` is set
to zero, no optional silence is hypothesized.

extra_questions.txt
-------------------
The file ``extra_questions.txt`` contains optional information for clustering
phonemes or characters and units during training. Each line contains contains
one group of phonemes, characters or units, seperated by whitespaces. Usually
this is used to indicate that all nonsilence phonemes or characters belong to
one group and all silence units to another. One line would contain all
nonsilence phonemes or characters and another line all silince units. Usually
it is used to differetiare between the different stress groups of phonemes. All
phonemes of one stress group will be listed in one line.

Creating the language directory
-------------------------------
The ``data/lang`` directory is created calling the command::

  utils/prepare_lang.sh data/local/dict <oov-dict-entry> data/local/lang data/lang
  
The ``<oov-dict-entry>`` has to be replaced by a word which is used for out of
vocabulary words, words which are not in the lexicon. If no out of vocabulary
words are present in the training data, any word can be used. Usually a word
mapping to a silince unit is used in the case of out of vocabulary words.

Optionally the parameter ``--sil-prob`` can be used to control the probability
of a silence unit to be hypothesized implicitely at the beginning of an
utterance and at the end of each word. If it is set to zero, no optional silence
is hypothesized. This does not influence explicitely modelled silence words.
