#!/usr/bin/python3
# -*- coding: utf-8 -*-

import logging
import os

import yaml

FORMAT = '[%(levelname)s-%(asctime)-15s]-%(message)s'
logging.basicConfig(format=FORMAT, level=logging.DEBUG)


# Convert yaml string to python dictionary
def __convert_yaml_to_dictionary(dictionary):
    return yaml.load(dictionary, Loader=yaml.FullLoader)


# Convert true and false to bool
def __check_bool_and_return(value):
    if isinstance(value, str):
        value_lower = value.lower()
        if value_lower == 'false':
            return False
        elif value_lower == 'true':
            return True
        else:
            return value
    else:
        return value


# Recursive search to get to the last element in keys list and add or modify it
def __modify_add_value(yaml_dictionary, keys, value, add):
    current_dictionary = yaml_dictionary

    # Explore the dictionary using the key in the keys list
    length = len(keys)
    for i in range(length - 1):
        logging.debug(keys[i])
        # Check if the next key is | meaning that is a string
        if keys[i + 1] == '|':
            logging.debug("Converting yaml string to dictionary")
            logging.debug(keys[i])
            logging.debug(current_dictionary)
            logging.debug(current_dictionary[keys[i]])
            new_dic = __convert_yaml_to_dictionary(current_dictionary[keys[i]])
            yaml_sub_dictionary = __modify_add_value(new_dic, keys[i + 2:], value, add)
            value = yaml.dump(yaml_sub_dictionary, default_flow_style=False)
            keys = keys[:i + 1]
            logging.debug(keys)
            break
        else:
            current_dictionary = current_dictionary[keys[i]]

    # Depending of the method, check if the targeted key exist (modify) or not (add)
    # if add and (keys[-1] in current_dictionary.keys()):
    #     logging.warning("Key to be added already exist %s" % (keys[-1]))
    # elif (not add) and (keys[-1] not in current_dictionary.keys()):
    #     logging.warning("Key to be modified doesn't exist %s " % (keys[-1]))

    # Check if the value to add is a yaml file
    if os.path.isfile(value):
        logging.debug(os.path.isfile(value))
        with open(value, "rb") as yam_file_to_add:
            value = __convert_yaml_to_dictionary(yam_file_to_add)

    # Change the last value and return the new dictionary
    current_dictionary[keys[-1]] = __check_bool_and_return(value)
    return yaml_dictionary


# Recursive search to get to the last element in keys list and remove it
def __remove_key(yaml_dictionary, keys):
    current_dictionary = yaml_dictionary
    length = len(keys)
    for i in range(length - 1):
        if keys[i + 1] == '|':
            logging.debug("Converting yaml string to dictionary")
            logging.debug(current_dictionary[keys[i]])
            new_dic = __convert_yaml_to_dictionary(current_dictionary[keys[i]])
            yaml_sub_dictionary = __remove_key(new_dic, keys[i + 2:])
            value = yaml.dump(yaml_sub_dictionary, default_flow_style=False)
            keys = keys[:i + 1]
            current_dictionary[keys[-1]] = value
            return yaml_dictionary
        else:
            current_dictionary = current_dictionary[keys[i]]
    try:
        del current_dictionary[keys[-1]]
    except KeyError:
        logging.warning("Key %s does not exist so it can not be remove" % (keys[-1]))
    return yaml_dictionary


# Recursive search to get to the last element in keys list and remove it
def __get_sub_dictionary(yaml_dictionary, keys):
    current_dictionary = yaml_dictionary
    length = len(keys)
    for i in range(length - 1):
        if keys[i + 1] == '|':
            logging.debug("Converting yaml string to dictionary")
            logging.debug(current_dictionary[keys[i]])
            new_dic = __convert_yaml_to_dictionary(current_dictionary[keys[i]])
            yaml_sub_dictionary = __remove_key(new_dic, keys[i + 2:])
            value = yaml.dump(yaml_sub_dictionary, default_flow_style=False)
            keys = keys[:i + 1]
            current_dictionary[keys[-1]] = value
            return yaml_dictionary
        else:
            current_dictionary = current_dictionary[keys[i]]
    return current_dictionary[keys[-1]]


# Generate list from input keys
def __generate_key_list(keys):
    new_list = []
    for key in keys.split(" "):
        if key.isdigit():
            new_list.append(int(key))
        else:
            new_list.append(str(key))
    return new_list


def remove_key(yaml_file, keys_list):
    # logging.debug("%s", yaml_file)
    with open(yaml_file, "rb") as yaml_file_in:
        yaml_dictionary = __convert_yaml_to_dictionary(yaml_file_in)
    # Generate the path list
    keys = __generate_key_list(keys_list)

    __remove_key(yaml_dictionary, keys)

    # Update the yaml file
    logging.debug(yaml_dictionary)
    with open(yaml_file, "w+") as yaml_file_out:
        yaml.dump(yaml_dictionary, yaml_file_out, default_flow_style=False)


def modify_add_value(yaml_file, keys_list, value, add=False):
    # logging.debug("%s", yaml_file)
    with open(yaml_file, "rb") as yaml_file_in:
        yaml_dictionary = __convert_yaml_to_dictionary(yaml_file_in)
    # Generate the path list
    keys = __generate_key_list(keys_list)

    __modify_add_value(yaml_dictionary, keys, value, add)

    # Update the yaml file
    logging.debug(yaml_dictionary)
    with open(yaml_file, "w+") as yaml_file_out:
        yaml.dump(yaml_dictionary, yaml_file_out, default_flow_style=False)


def get_sub_dictionary(yaml_file, keys_list):
    # logging.debug("%s", yaml_file)
    with open(yaml_file, "rb") as yaml_file_in:
        yaml_dictionary = __convert_yaml_to_dictionary(yaml_file_in)
    # Generate the path list
    keys = __generate_key_list(keys_list)
    return yaml.dump(__get_sub_dictionary(yaml_dictionary, keys), default_flow_style=False)
