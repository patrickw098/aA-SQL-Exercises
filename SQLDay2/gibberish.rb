SELECT SUM(question_likes.user_id) / CAST(COUNT(questions.user_id) AS FLOAT)
FROM questions
LEFT OUTER JOIN
question_likes
ON
questions.id = question_likes.questions_id
GROUP BY questions.id;
