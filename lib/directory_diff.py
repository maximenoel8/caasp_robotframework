#!/usr/bin/python3
# -*- coding: utf-8 -*-

import difflib
import logging
from filecmp import dircmp

FORMAT = '[%(levelname)s-%(asctime)-15s]-%(message)s'
logging.basicConfig(format=FORMAT, level=logging.DEBUG)
result = {
    "file_diff": {},
    "only_from": {},
    "only_to": {}
}


def print_diff_value(file1, file2):
    with open(file1) as f1:
        f1_text = f1.readlines()
    with open(file2) as f2:
        f2_text = f2.readlines()

    return difflib.context_diff(f1_text, f2_text, fromfile=file1, tofile=file2, lineterm='\n')


def print_diff_files(diff_element):
    for name in diff_element.diff_files:
        logging.debug("diff_file %s found in %s and %s" % (name, diff_element.left, diff_element.right))
        result["file_diff"][name] = list(
            print_diff_value(diff_element.left + "/" + name, diff_element.right + "/" + name))
    for sub_dcmp in diff_element.subdirs.values():
        print_diff_files(sub_dcmp)
    logging.debug(diff_element.right_only)
    result["only_from"] = diff_element.left_only
    result["only_to"] = diff_element.right_only


def compare_directory_and_get_diff(directory1, directory2):
    diff_element = dircmp(directory1, directory2)
    print_diff_files(diff_element)
    return result
