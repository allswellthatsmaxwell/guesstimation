library(readr)
library(dplyr)
library(magrittr)
library(ggplot2)

MAX_ANSWER_ALLOWED <- 1.00e153 ## bigger numbers break geom_histogram idk why
IGNORE_QUESTION_PATTERN <- 'What percent of respondents to this survey'
SHORT_NAMES_FPATH <- '../data/short_names.psv'
RESPONSES_FNAME <- '../data/long_dat.csv'
ANSWERS_FNAME <- '../data/answers.psv'
QUESTIONS_COL <- 'short_question'

get_kth_max <- function(dat, k) {
  dat %>%
    group_by(question) %>%
    mutate(rnk = n() - rank(answer)) %>%
    dplyr::filter(rnk == k) %>%
    distinct(question, answer)
}

get_question_stats <- function(dat) {
  second_maxs <- get_kth_max(dat, 2) %>% rename(second_highest_response = answer)
  third_maxs <- get_kth_max(dat, 3) %>% rename(third_highest_response = answer)
  
  dat %>%
    group_by(question) %>%
    summarize(answers = n(), mean_response_value = mean(answer),
              median_response_value = median(answer),
              highest_response = max(answer), lowest_response = min(answer)) %>%
    left_join(second_maxs, by = 'question') %>%
    left_join(third_maxs, by = 'question')
}

get_group_stats <- function(dat) {
  dat %>%
    dplyr::select(question_group, timestamp) %>%
    dplyr::distinct() %>%
    group_by(question_group) %>%
    dplyr::summarize(surveys_taken = n())
}

replace_question_with_short_version <- 
  function(dat, short_names_fpath = SHORT_NAMES_FPATH) {
    short_names_df <- read_delim(short_names_fpath, '|')
    dat %>%
      left_join(short_names_df, by = 'question') %>%
      mutate(question = short_question) %>% 
      select(-short_question)
}

read_response_data <- 
  function(fpath, 
           short_names_fpath = SHORT_NAMES_FPATH,
           use_short_names = TRUE,
           max_answer_allowed = MAX_ANSWER_ALLOWED,
           ignore_pattern = IGNORE_QUESTION_PATTERN) {
  dat <- fpath %>%
    read_csv() %>%
    dplyr::filter(!grepl(IGNORE_QUESTION_PATTERN, question)) %>%
    mutate(answer = pmin(answer, max_answer_allowed))
  if (use_short_names) {
    dat %<>% replace_question_with_short_version(short_names_fpath)
  }
  dat
}

read_answers_data <- 
  function(fpath, short_names_fpath = SHORT_NAMES_FPATH,
           use_short_names = TRUE) {
  dat <- read_delim(fpath, delim = '|')
  if (use_short_names) {
    dat %<>% replace_question_with_short_version(short_names_fpath)
  }
  dat
}

get_timestamp_ranks <- function(dat) {
  dat %>%
    group_by(question_group, question) %>% 
    arrange(question_group, question, desc(answer)) %>% 
    mutate(rnk = 1:n()) 
}

make_facetted_histograms_plot <- function(questions_dat, answers_dat,
                                          trans = identity) {
  responses_summary <- questions_dat %>%
    get_question_stats()
  answers_dat %<>% dplyr::filter(question %in% questions_dat$question)
  questions_dat %>%
    ggplot(aes(x = trans(answer))) +
    geom_histogram(bins = 15) +
    theme_bw() +
    facet_wrap(~question, scales = "free") +
    geom_vline(data = answers_dat, aes(xintercept = trans(true_answer)),
               color = 'red') +
    geom_vline(data = responses_summary, aes(xintercept = trans(mean_response_value)),
               color = '#33B5FF') +
    geom_vline(data = responses_summary, aes(xintercept = trans(median_response_value)),
               color = '#7fff00')
}


USE_SHORT_NAMES <- TRUE

dat <- read_data(RESPONSES_FNAME, use_short_names = USE_SHORT_NAMES)
answers_dat <- read_answers_data(ANSWERS_FNAME)

groups_to_investigate <- c("Group A", "Group B", "Group C")
groups_to_predict_for <- c("Group D")

invs_dat <- dat %>% dplyr::filter(question_group %in% groups_to_investigate)
pred_dat <- dat %>% dplyr::filter(question_group %in% groups_to_predict_for)

question_stats_table <- invs_dat %>% 
  get_question_stats() %>%
  left_join(answers_dat, by = "question")
group_stats_table <- dat %>% get_group_stats()

## Are there guessers guessing consistently high or consistently low?
timestamp_ranks <- invs_dat %>% 
  get_timestamp_ranks()

median_ranks <- timestamp_ranks %>%
  group_by(question_group, timestamp) %>%
  dplyr::summarize(median_rank = median(rnk)) %>%
  arrange(median_rank)

median_ranks %>%
  ggplot(aes(x = median_rank)) +
  geom_histogram(bins = 20) +
  theme_bw() +
  facet_wrap(~question_group)

timestamp_ranks %>%
  ggplot(aes(x = timestamp, y = rnk)) +
  geom_point() +
  theme_bw() +
  facet_wrap(~question_group)

invs_dat %>%
  make_facetted_histograms_plot(answers_dat, trans=log2)
  
## Next, look into outlier detection & removal / dampening.

