require 'sqlite3'
require 'singleton'

 class QuestionsDatabase < SQLite3::Database
   include Singleton

   def initialize
     super('questions.db')
     self.type_translation = true
     self.results_as_hash  = true
   end
end

class User
  attr_accessor :fname, :lname
  attr_reader :id

  def self.all
    data = QuestionsDatabase.instance.execute("Select * FROM users")
    data.map { |datum| User.new(datum) }
  end

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def self.find_by_id(id)

    user = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        users
      WHERE
        id = ?
    SQL
    return nil unless user.length > 0

    User.new(user.first)
  end

  def self.find_by_name(name)
    fname = name.split(" ")[0]
    lname = name.split(" ")[-1]

    user = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL

    return nil unless user.length > 0

    User.new(user.first)
  end

  def authored_questions
    Question.find_by_author_id(self.id)
  end

  def authored_replies
    Reply.find_by_user_id(self.id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(self.id)
  end

  def follow_question(question_id)
    QuestionsDatabase.instance.execute(<<-SQL, question_id, self.id)

      INSERT INTO
        question_follows(questions_id, user_id)
      VALUES
        (? , ?)
    SQL
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(self.id)
  end

  def like_question(question_id)
    QuestionsDatabase.instance.execute(<<-SQL, question_id, self.id)

      INSERT INTO
        question_likes(questions_id, user_id)
      VALUES
        (? , ?)
    SQL
  end

  def average_karma
    # questions =

  end

end

class Question
  attr_accessor :title, :body
  attr_reader :user_id, :id

  def self.all
    data = QuestionsDatabase.instance.execute("SELECT * FROM questions")
    data.map { |datum| Question.new(datum) }
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @user_id = options['user_id']
  end

  def self.find_by_id(id)
    question = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        questions
      WHERE
        id = ?
    SQL

    return nil unless question.length > 0

    Question.new(question.first)
  end

  def self.find_by_author_id(user_id)
    question = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        questions
      WHERE
        user_id = ?
    SQL

    return nil unless question.length > 0

    Question.new(question.first)
  end

  def author
    User.find_by_id(self.user_id)
  end

  def replies
    Reply.find_by_question_id(self.id)
  end

  def followers
    QuestionFollow.followers_for_question(self.id)
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def likers
    QuestionLike.likers_for_question_id(self.id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(self.id)
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end

  def create
    raise "#{self} already in database" if @id
    data = QuestionsDatabase.instance.execute(<<-SQL, @title, @body, @user_id)
      INSERT INTO
        questions(title, body, user_id)
      VALUES
        (?, ?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end

end

class Reply
  attr_accessor :body
  attr_reader :parent_id, :user_id, :question_id, :id

  def self.all
    data = QuestionsDatabase.instance.execute("SELECT * FROM replies")
    data.map { |datum| Reply.new(datum) }
  end

  def initialize(options)
    @id = options['id']
    @body = options['body']
    @parent_id = options['parent_id']
    @user_id =  options['user_id']
    @question_id =  options['question_id']
  end

  def create
    raise "#{self} already in database" if @id
    data = QuestionsDatabase.instance.execute(<<-SQL, @body, @parent_id, @user_id, @question_id)
      INSERT INTO
        replies(body, parent_id, user_id, question_id)
      VALUES
        (?, ?, ?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end


  def self.find_by_id(id)
    reply = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        replies
      WHERE
        id = ?
    SQL

    return nil unless reply.length > 0
    Reply.new(reply.first)
  end

  def self.find_by_user_id(user_id)
    reply = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        replies
      WHERE
        user_id = ?
    SQL

    return nil unless reply.length > 0

    Reply.new(reply.first)
  end

  def self.find_by_question_id(question_id)
    reply = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        replies
      WHERE
        question_id = ?
    SQL

    return nil unless reply.length > 0

    Reply.new(reply.first)
  end

  def author
    User.find_by_id(self.user_id)
  end

  def question
    Question.find_by_id(self.question_id)
  end

  def parent_reply
    Reply.find_by_id(self.parent_id)
  end

  def child_replies
    replies = QuestionsDatabase.instance.execute(<<-SQL, self.id)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_id = ?
    SQL

    return nil unless replies.length > 0

    replies.map { |reply| Reply.new(reply) }
  end

end

class QuestionFollow

  def self.followers_for_question(question_id)
    followers = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        user_id
      FROM
        question_follows
      WHERE
        questions_id = ?
    SQL

    followers.map { |follower| User.find_by_id(follower['user_id']) }
  end

  def self.followed_questions_for_user_id(user_id)
    questions = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        questions_id
      FROM
        question_follows
      WHERE
        user_id = ?
    SQL

    questions.map { |question| Question.find_by_id(question['questions_id']) }
  end

  def self.most_followed_questions(n)
    most_followed = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions_id
      FROM
        question_follows
      GROUP BY
        questions_id
      ORDER BY
        COUNT(*) DESC
      LIMIT
        ?
    SQL

    most_followed.map { |follows| Question.find_by_id(follows['questions_id'])}
  end


end

class QuestionLike

  def self.likers_for_question_id(question_id)
    likers = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        user_id
      FROM
        question_likes
      WHERE
        questions_id = ?
    SQL

    likers.map { |liker| User.find_by_id(liker['user_id']) }
  end

  def self.num_likes_for_question_id(question_id)
    likers = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        Count(*)
      FROM
        question_likes
      WHERE
        questions_id = ?
      GROUP BY
        questions_id
    SQL
    likers.first['Count(*)']
  end

  def self.liked_questions_for_user_id(user_id)
    questions = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        questions_id
      FROM
        question_likes
      WHERE
        user_id = ?
    SQL

    questions.map { |question| Question.find_by_id(question['questions_id'])}
  end

  def self.most_liked_questions(n)
    likers = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions_id, COUNT(*)
      FROM
        question_likes
      GROUP BY
        questions_id
      ORDER BY
        COUNT(*) DESC
      LIMIT
        ?
    SQL

    likers.map { |question| Question.find_by_id(question['questions_id'])}
  end



end
