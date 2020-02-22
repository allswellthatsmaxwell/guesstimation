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

def is_email_question(s):
    return "leave a contact method here" in s
    
def remove_emails(long_dat):
    return long_dat[~long_dat['question'].apply(is_email_question)]

def numerize_string_answers(answers):
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

def convert_to_float(frac_str):
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
    outpath = 'data/long_dat.csv'
    dat = read_data(fpath)
    long_dat = wide_to_long(dat)
    long_dat = remove_emails(long_dat)
    long_dat['answer'] = numerize_string_answers(long_dat['answer'])
    long_dat = long_dat[~long_dat['answer'].apply(nullish)]
    write_data(long_dat, outpath)
