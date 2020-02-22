import pandas as pd
import sys

COL_RENAMES = {
    'Timestamp': 'timestamp',
    'The 40 questions in this survey have been placed into four arbitrary groups of 10, to make the survey shorter. Pick a group of questions, and if you like it you can take this survey again and pick another group.': 'question_group'
}

def wide_to_long(dat):
    questions_answers = {}
    for colname in dat.columns:
        if colname not in ('timestamp', 'question_group'):
            questions_answers[colname] = [
                x for x in dat[colname] if x is not None
                and not pd.isnull(x)]
    rows = []
    for question, answers in questions_answers.items():
        for answer in answers:
            row = (question, answer)
            rows.append(row)
    return pd.DataFrame(rows, columns=['question', 'answer'])

def read_data(fpath):
    dat = pd.read_csv(fpath)
    return dat.rename(columns=COL_RENAMES)

def write_data(dat, fpath):
    dat.to_csv(fpath, index=False)

fpath = sys.argv[1]
outpath = 'data/long_dat.csv'
dat = read_data(fpath)
long_dat = wide_to_long(dat)
write_data(long_dat, outpath)
