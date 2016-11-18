#!/usr/bin/env python3
import argparse
import os


def utt2spk_line(key, _):
    """ Get utterance id to speaker id antry. This function assumes the
    utterance id to be in the form 'SPKUTTID', where 'SPK' is the speaker id.
    Everything after 'SPK' will be cut of.
    
    :param key: utterance id
    
    :return:
    utterance id speaker id (separated by space)
    """
    return '{} {}\n'.format(key, key[:3])


def wav_scp_line(key, value):
    """ Generate wav.scp line.
    
    :param key: recording id
    :param value: list with fist element to contain full filename
    
    :return:
    recording id wav file (separated by space)
    """
    file = value[0]
    return '{} /scratch/owb/Downloads/kaldi/tools/sph2pipe_v2.5/sph2pipe -f wav {} |\n'.format(key, file)


def word_text_line(key, value):
    """ Generate transcription entry in text file
    
    :param key: utterance id
    :param value: list with second element to contain sequence of words (list)
    
    :return:
    recording id transcription (separated by space and each entry in
    transcription separated by space as well)
    """
    transcription = value[1]
    return '{} {}\n'.format(key, ' '.join(transcription))


def write_data(files, data_dir, text, wav_scp, utt2spk):
    """ Write files in data directory.
    
    :param files: dictionary with key beeing recording id and value beeing a list
        containing the elements [wav_file, transcription]
    :param data_dir: location of data dir to create
    :param text: function to generate transcription entry for text file
    :param wav_scp: function to generate wav file entry for wav.scp
    :param utt2spk: fucntion to generate utt2spk entry in utt2spk file    
    """
    os.makedirs(data_dir, exist_ok=True)
    with open('{}/text'.format(data_dir), 'w') as text_fid, \
            open('{}/wav.scp'.format(data_dir), 'w') as wav_fid, \
            open('{}/utt2spk'.format(data_dir), 'w') as utt2spk_fid:
        for item in sorted(files.items()):
            text_fid.write(text(*item))
            wav_fid.write(wav_scp(*item))
            utt2spk_fid.write(utt2spk(*item))


def read_lab(key, labs_dir, lab_suffix):
    """ Read label file for given key. Filename is constructed as
    {labs_dir}/{key}{lab_suffix}.lab
    
    :param key: key to read file for.
    :param labs_dir: directory containing labels.
    :param lab_suffix: addtional suffix to add to key to get label file.
    
    :return: transcript list
    """
    transcript = list()
    try:
        with open('{}/{}{}.lab'.format(labs_dir, key, lab_suffix)) as lab_fid:
            for line in lab_fid:
                transcript_line = line.strip().split()
                try:
                    transcript.append(transcript_line[2])
                except IndexError:
                    transcript.append(transcript_line[0])
    except IOError:
        print('No transcription for key {} with suffix {} in {}'.format(
            key, lab_suffix, labs_dir))
    return transcript


def read_keys(keys_file):
    """ Read keys file line by line.

    :param keys_file: keys filename
    
    :return: set of keys
    """
    with open(keys_file) as keys_fid:
        return {line.strip() for line in keys_fid}


def read_files(scp_file, keys, labs_dir, lab_suffix):
    """ Read files list for given keys.
    
    :param scp_file: scp filename
    :param keys: set of keys
    :param labs_dir: directory of label files
    :param lab_suffix: suffix to add to key to get label file
    
    :return:
    Dictionary with key as key and value (file, transcript [, start, end])
    Where file is the wav filename, transcript is the transcription and
    additinally start and end times of the segment
    """
    files = dict()
    with open(scp_file) as scp_fid:
        for line in scp_fid:
            file, key = line.strip().split(':')
            if key in keys:
                if labs_dir is not None:
                    transcript = read_lab(key, labs_dir, lab_suffix)
                else:
                    transcript = ['SPN']
                if len(transcript) > 0:
                    try:
                        file, start, end = file.split('[')
                        files[key] = (file, transcript, start, end)
                    except ValueError:
                        files[key] = (file, transcript)
    return files


def read_data(scp_file, keys_file, labs_dir, lab_suffix):
    """ Read all data from the amdtk experiment
    
    :param scp_file: scp filename
    :param keys_file: keys filename
    :param labs_dir: directory of label files
    :param lab_suffix: suffix to add to key to get label file
    
    :return:
    Dictionary with key as key and value (file, transcript [, start, end])
    Where file is the wav filename, transcript is the transcription and
    additinally start and end times of the segment
    """
    
    keys = read_keys(keys_file)
    return read_files(scp_file, keys, labs_dir, lab_suffix)


def write_segments(files, data_dir):
    """ Write segments file. It is asumed that the recording id is the same as
    the utterance is and we just add the start and end times to cut out
    the segments of interest.
    
    :param files: Dictionary with key as key and value
      (file, transcript [, start, end])
    """
    with open('{}/segments'.format(data_dir), 'w') as fid_segments:
        for item in sorted(files.items()):
            key, (_, _, start, end) = item
            fid_segments.write('{} {} {} {}\n'.format(key, key, start, end))


def main():
    parser = argparse.ArgumentParser(description='Create data directory')
    parser.add_argument('-s', '--scp_file', type=str, required=True)
    parser.add_argument('-k', '--keys_file', type=str, required=True)
    parser.add_argument('-l', '--labs_dir', type=str)
    parser.add_argument('-d', '--data_dir', type=str, required=True)
    parser.add_argument('-a', '--lab_suffix', type=str, default='')
    parser.add_argument('-t', '--write_segments', action='store_true',
                        default=False)
    args = parser.parse_args()

    files = read_data(args.scp_file, args.keys_file, args.labs_dir,
                      args.lab_suffix)

    write_data(files, args.data_dir, word_text_line, wav_scp_line, utt2spk_line)

    if args.write_segments:
        write_segments(files, args.data_dir)


if __name__ == '__main__':
    main()
