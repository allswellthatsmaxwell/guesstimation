#Parsing survey data for estimations
import csv
import re
import math
import sys

filename = sys.argv[1]

csvreader = csv.reader(open(filename,'r'))

num_words = {'million':10**6,'billion':10**9,'trillion':10**12,
             'thousand':10**3,'k':10**3,'%':0.01}

ans_dict = {
    'iowa': None,
    'rhode island':None,
    'oklahoma':None,
    'nevada':None,
    '40~ au':None,
    '300m':3*10**8,
    '1 million years':10**6,
    '30\'000':30000,
    '15km':15000,
    '3x10^9':3*10**9,}

def drakeparse(ans):
    ans=ans.lower()
    if ans=='none':
        return None
    return float(ans)

def parse(ans):
    if ans=='':
        return None
    ans=re.sub(',','',ans.lower().strip())
    try:
        return float(ans)
    except ValueError:
        if ans in ans_dict:
            return ans_dict[ans]
        if '@' in ans: #email address
            return ans
        if '*' in ans:
            s=ans.split("*")
            if '^' in s[1]:
                return float(s[0])*(10**int(s[1].split('^')[1]))
        if '^' in ans:
            s=ans.split()[0].split('^')
            return float(s[0])**float(s[1])
        if '/' in ans or ':' in ans:
            if '/' in ans:
                s=ans.split('/')
            else:
                s=ans.split(':')
            n=float(s[0])
            d=float(''.join(c for c in s[1] if c.isdigit()))
            return n/d
        for key in num_words:
            if ans[-len(key):]==key:
                return float(ans[:-len(key)])*num_words[key]
        return drakeparse(input(ans+" = "))

rows=[]
for row in csvreader:
    rows.append(row)

#Fixing specific bad inputs
rows[40][8]='0.23'
rows[40][10]='3 million'

def cfind(s):
    for i in range(len(rows)):
        for j in range(len(rows[0])):
            if type(rows[i][j])==str and s in rows[i][j]:
                print (rows[0][j],i,j)
                print(rows[i][j])
    return 0


for i in range(1,len(rows)):
    nrow=rows[i][:2]
    for j in range(2,len(rows[i])):
        a=rows[i][j]
        if j in [12,23,34,45]:
            p=a
        else:
            p=parse(a)
        if len(a)>0:
            pass
            #print(a,p)
        nrow.append(p)
    #print(nrow)
    rows[i]=nrow[:]
    #print(rows[i])

A=[2,3,4,5,6,7,8,9,10]
B=[13,14,15,16,17,18,19,20,21]
C=[24,25,26,27,28,29,30,31,32]
D=[35,36,37,38,39,40,41,42,43]
questions=A+B+C+D
dk=[11,22,33,44] #dunning-keuger questions

answers=[0]*45
actual_answers=[1737.4,39.2, 14.5+1/15, 70,
                150, 0.1892,0.0261,22247769299095,
                1100000,1084170,563,1.846,55.94,
                374.38,8.96,0.43,2311273,193,
                329214122,50000,126020000,19194,
                4120000,4634,364,6*10**11,38262,
                621,2.45*10**18,146801931,382,
                0.904,111,2369142,108,70435]
                

def get_responses(q_ind):
    return sorted([rows[i][q_ind] for i in range(1,len(rows)) if rows[i][q_ind]!=None])

#munge data for specific questions people were silly on
for r in rows[1:]:
    if type(r[7])==float: #this is the france question
        if 1<r[7]<=100: #someone entered percent instead of fraction
            r[7]/=100
        elif r[7]>100:
            r[7]=None
    
    

#
#
#
# ACTUAL FUNCTIONS
#
#
#

def median(l):
    if len(l)%2==0:
        return (l[len(l)//2]+l[len(l)//2+1])/2
    return l[len(l)//2]

def arithmetic_mean(l):
    return sum(l)/len(l)

def prob_transform(l):
    return [e/(1-e) for e in l]

def log_transform(l):
    return [math.log(e) for e in l]

#print(questions[0])
#exit

question_names = rows[0]
#print(rows[0])
#exit

for i, question_idx in enumerate(questions):
    responses = get_responses(question_idx)
    question_name = question_names[i]
    responses_str = ','.join([str(x) for x in responses])
    s = f"{question_name}|{responses_str}"
    print(s)
    #if actual_answers[i]<g[0] or actual_answers[i]>g[-1]:
    #    print(rows[0][questions[i]],actual_answers[i] )

