"""
Functions for transforming the raw meetup data to long-format
(one row per question-response pair). If running from CMD, pass
the path to the wide raw file as the first argument to the script.
"""

import pandas as pd
import sys
from typing import List, Any, Iterable

COL_RENAMES = {
    'Timestamp': 'timestamp',
    'The 40 questions in this survey have been placed into four arbitrary groups of 10, to make the survey shorter. Pick a group of questions, and if you like it you can take this survey again and pick another group.': 'question_group'
}

def wide_to_long(wide_dat: pd.DataFrame) -> pd.DataFrame:
    """
    Expands the wide-format raw input wide_data, with one column per question,
    into a one-line-per-(question-answer-pair) wide_dataframe.
    """
    non_question_cols = ['timestamp', 'question_group']
    question_cols = [c for c in wide_dat.columns if c not in non_question_cols] 
    all_new_rows = []
    for _, row in wide_dat.iterrows():
        new_rows = handle_wide_row(row, non_question_cols, question_cols)
        all_new_rows.extend(new_rows)
    return pd.DataFrame(
        all_new_rows, columns = non_question_cols + ['question', 'answer'])

def handle_wide_row(row, non_question_cols: Iterable[str],
                    question_cols: Iterable[str]) -> List[Any]:
    """
    :param row: One row from the original raw wide file,
    as a named row (such as is given by iterrows over a dataframe).
    
    :param non_question_cols: columns corresponding to metadata
    to keep for each response. Names that must be present in row.

    :param question cols: columns corresponding to questions.
    Names that must be present in row.
    """
    survey_metadata = [row[col] for col in non_question_cols]
    new_rows = []
    for question in question_cols:
        answer = row[question]
        if not nullish(answer):
            new_row = survey_metadata + [question, answer]
            new_rows.append(new_row)
    return new_rows
 
def read_data(fpath) -> pd.DataFrame:
    """ :param fpath: path to a csv """
    dat = pd.read_csv(fpath)
    return dat.rename(columns=COL_RENAMES)

def write_data(dat, fpath):
    """ writes dat as a csv to fpath """
    dat.to_csv(fpath, index=False)

def is_email_question(s: str) -> bool:
    return "leave a contact method here" in s
    
def remove_emails(long_dat: pd.DataFrame) -> pd.DataFrame:
    """ removes the rows that could have people's emails as answers. """
    return long_dat[~long_dat['question'].apply(is_email_question)]

def numerize_string_answers(answers: Iterable) -> List[float]:
    """
    Fixes answers noticed to be hard to parse, e.g. maps "21 trillion" 
    to its integer representation. Also handles fractions and other weird stuff.
    A list the same length as the input is returned, with the newly-fixed values.
    If there's no way to parse an answer to a number (e.g. the answer is "Iowa"),
    returns None in that answer's position.
    """
    replaces = {
        '20%': 0.2,
        '3.50%': 0.035,
        'wyoming, 0.23/1~ish': 0.23,
        '10^10 (10000000000)': 10**10,
        '3x10^9': 3 * 10 **9,
        '21 trillion': 21 * 10**9,
        '3~ million': 3 * 10**6,
        
        ## answers to ratio question - 300% or 800% impossible
        '3:1': 1/3,
        '8:1': 1/8,
        
        "30'000": 30000,        
        '1 million years': 10**6,
        '2/3rds': 2/3,
        '40~ AU': 5.984e+12, ## meters
        '300m': 300 * 10**6, ## pop of US question - m probably millions
        '15km': 15 * 1000        
    }
    new_answers = []
    for answer in answers:
        try:
            new_answer = replaces[answer]
        except KeyError:
            try:                
                answer = str(answer)
                answer = (
                    answer.replace(',', '').
                    replace('^', '**').
                    replace('million', '* 10**6'))
                
                new_answer = eval(answer)
                
            except (ValueError, NameError, SyntaxError):
                print(f'Failed to parse answer: {answer}')    
                new_answer = None

        new_answers.append(new_answer)
    return new_answers

def convert_to_float(frac_str: str) -> float:
    """ 
    coverts fractions (e.g. 1/3) to their python float value. 
    Works for normal floats too (3.0 -> 3.0) 
    """
    try:
        return float(frac_str)
    except ValueError:        
        num, denom = frac_str.split('/')
        try:
            leading, num = num.split(' ')
            whole = float(leading)
        except ValueError:
            whole = 0
        frac = float(num) / float(denom)
        return whole - frac if whole < 0 else whole + frac

def nullish(answer):
    return answer is None or pd.isnull(answer)
    
if __name__ == '__main__':
    fpath = sys.argv[1]
    outpath = sys.argv[2]
    dat = read_data(fpath)
    long_dat = wide_to_long(dat)
    long_dat = remove_emails(long_dat)
    long_dat['answer'] = numerize_string_answers(long_dat['answer'])
    long_dat = long_dat[~long_dat['answer'].apply(nullish)]
    write_data(long_dat, outpath)
