import jester, json, norm/sqlite, htmlgen

db("msgs.db", "", "", ""):
  type
    Post = object
      parent: int
      name: string
      message: string

#withDb:
  #createTables(force=false)
proc threadCount(): int =
  withDb:
    result = Post.getMany(
      cond = "parent = 0",
      limit = 100
    ).len

proc postCount(): int =
  withDb:
    result = Post.getMany(
      limit = 100
    ).len


proc storeMsg(msg: JsonNode) =
  var token = to(msg, Post)
  withDb:
    token.insert()

proc lookupThread(op: int): seq[Post] =
  withDb:
    result = Post.getMany(
      cond = "parent = ?",
      params = op,
      limit = 100
    )

routes:
  get "/":
    withDb:
      resp h1("Welcome to nChan! ", threadCount().intToStr, " threads, ", postCount().intToStr, " posts")
  get "/@thread":
    withDb:
      var op = Post.getOne(parseInt @"thread")
      if (op.parent == 0):
        var posts = lookupThread(op.id)
        var hi = op.name & ": " & op.message & '\n'
        for i in posts:
          hi.add(i.name & ": " & i.message & '\n')
        resp $hi
  post "/":
    var response = "invalid parent"
    let submission = parseJson request.body
    submission["id"] = %* 0 #placeholder id field
    withDb:
      let parent = submission["parent"].getInt

      # A post must either:
      # - an opening post (have a parent of 0)
      # - a reply to one (have a parent with a parent of 0)
      if parent == 0:
        storeMsg(submission)
        response = "thread submitted!"
      else:
        try:
          let op = Post.getOne parent
          if op.parent == 0:
            storeMsg(submission)
            response = "reply submitted to thread!"
        except:
          discard
    resp $response
