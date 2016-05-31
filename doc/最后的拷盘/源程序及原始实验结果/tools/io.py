import json
import csv


def to_json(output_file_name, data):
    """
    Save the specified data to the specified JSON file.
    :param output_file_name: the output JSON file name
    :param data: the data to save
    :return: None
    """
    with open(output_file_name, 'w') as output_file:
        json.dump(data, output_file, indent=4, separators=(',', ': '))


def from_json(input_file_name):
    """
    Load the data from the specified JSON file name
    :param input_file_name: the input JSON file name
    :return: the data that is loaded from the specified JSON file
    """
    with open(input_file_name, 'r') as input_file:
        return json.load(input_file)


def to_csv(output_file_name, results, fields):
    """
    Save the specified fields in the results to the specified CSV file.
    :param output_file_name: the output CSV file name
    :param results: the list of results
    :param fields: the list of fields
    :return: None
    """
    with open(output_file_name, 'w') as output_file:
        writer = csv.writer(output_file, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL)

        writer.writerow([field[0] for field in fields])

        for result in results:
            writer.writerow([field[1](result) for field in fields])