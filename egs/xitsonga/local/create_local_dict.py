#!/usr/bin/env python3
import argparse
import os


def get_words(text):
    """ Get set containing all words in text file, first entry is utterance id,
    followed by words separated by spaces.
    
    :param text: text file name
    :return: set of words
    """
    with open(text) as fid_text:
        return {word for line in fid_text for word in line.strip().split()[1:]}


def write_local_dict(words, local_dict):
    """ Write data to local dict directory creating all needed files. Assumes
    each word to be one phoneme.
    
    :param words: set of words
    :param local_dict: loacl dict path
    """
    with open('{}/lexicon.txt'.format(local_dict), 'w') as fid_lexicon:
        for word in sorted(words):
            fid_lexicon.write('{} {}\n'.format(word, word))

    with open('{}/nonsilence_phones.txt'.format(local_dict), 'w') \
            as fid_nonsilence:
        fid_nonsilence.write('\n'.join(sorted(words)) + '\n')

    with open('{}/silence_phones.txt'.format(local_dict), 'w') as fid_silence:
        fid_silence.write('sil\n')

    with open('{}/optional_silence.txt'.format(local_dict), 'w') \
            as fid_optional_silence:
        fid_optional_silence.write('sil\n')

    with open('{}/extra_questions.txt'.format(local_dict), 'w') \
            as fid_extra_questions:
        fid_extra_questions.write('sil\n')
        fid_extra_questions.write(' '.join(sorted(words)) + '\n')


def main():
    parser = argparse.ArgumentParser(description='Create local dict directory')
    parser.add_argument('-t', '--text', type=str, required=True)
    parser.add_argument('-d', '--local_dict', type=str, required=True)
    args = parser.parse_args()

    words = get_words(args.text)

    os.makedirs(args.local_dict, exist_ok=True)
    write_local_dict(words, args.local_dict)


if __name__ == '__main__':
    main()
