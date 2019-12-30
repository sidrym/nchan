import jester, json, norm/sqlite
import karax / [karaxdsl, vdom]

db("msgs.db", "", "", ""):
  type
    # A post must either:
    # - an opening post (have a parent of 0)
    # - a reply to one (have a parent with a parent of 0)
    Post = object
      parent: int
      subject: string
      name: string
      message: string

withDb:
  createTables(force=true)

proc threadCount(): int =
  withDb:
    result = Post.getMany(
      cond = "parent = 0",
      limit = 100
    ).len

proc lookupOps(): seq[Post] =
  withDb:
    result = Post.getMany(
      cond = "parent = 0",
      limit = 100
    )

proc postCount(): int =
  withDb:
    result = Post.getMany(
      limit = 100
    ).len

proc lookupThread(op: int): seq[Post] =
  withDb:
    #result.add Post.getOne op
    result.add Post.getMany(
      cond = "parent = ?",
      params = op,
      limit = 100
    )

proc storePost(parent: int, submission: Table[system.string, system.string]) =
  var post = Post()
  post.parent = parent
  for field, val in submission.pairs:
    case field:
    of "message": post.message = val.strip()
    of "name": post.name = if val == "": "Anonymous" else: val.strip()
    of "subject": post.subject = val.strip()
  withDb:
    post.insert()

## TODO: find a way to use this in renderHome and renderThread
#proc msgForm*(op: Post): string =
#  let vnode = buildHtml(tdiv(class = "form")):
#    form(`method` = "POST", action = "/" & op.id.intToStr):
#      input(`type` = "text", `placeholder` = "name", `name` = "name")
#      input(`type` = "text", `placeholder` = "message", `name` = "message")
#      button(`type` = "submit"): text "submit"
#  result = $vnode

proc renderThread*(op: Post): string =
  var posts = lookupThread(op.id)
  let vnode = buildHtml(tdiv(class = "thread")):
    text "Thread #" & op.id.intToStr & ": "
    bold: text op.subject
    p:
      bold: text op.name
      text ": " & op.message
    ul:
      for i in posts:
        li:
          text i.id.intToStr & ". "
          bold: text i.name
          text ": " & i.message
    # TODO: make this its own function, use enctype = "multipart/form-data"
    form(`method` = "POST", action = "/" & op.id.intToStr):
      input(`type` = "text", `placeholder` = "name", `name` = "name")
      input(`type` = "text", `placeholder` = "message", `name` = "message")
      button(`type` = "submit"): text "submit"
  result = $vnode

proc renderHome*(): string =
  let vnode = buildHtml(tdiv(class = "home")):
    h1: text "Welcome to nChan!"
    h4: text threadCount().intToStr &
        " threads, " & postCount().intToStr & " posts"
    h4: text "Recent threads:"
    ul:
      for i in lookupOps():
        li: a(href = i.id.intToStr):
          if i.subject == "":
            text i.message
          else:
            bold: text i.subject
            text ": " & i.message
    # TODO: make this its own function, use enctype = "multipart/form-data"
    form(`method` = "POST", action = "/0"):
      input(`type` = "text", `placeholder` = "subject", `name` = "subject")
      input(`type` = "text", `placeholder` = "name", `name` = "name")
      input(`type` = "text", `placeholder` = "message", `name` = "message")
      button(`type` = "submit"): text "submit"
  result = $vnode


routes:
  get "/":
    resp renderHome()
  get "/@thread":
    withDb:
      try:
        var op = Post.getOne(parseInt @"thread")
        if (op.parent == 0):
          resp renderThread(op)
      except:
        discard
    resp Http404, "Thread not found!"
  post "/@thread":
    var response = "invalid parent"
    let submission = params(request)
    let parent = parseInt @"thread"
    withDb:
      if parent == 0:
        storePost(parent, submission)
        response = "thread submitted!"
      else:
        try:
          let op = Post.getOne parent
          if op.parent == 0:
            storePost(parent, submission)
            response = "reply submitted to thread!"
        except:
          discard
    resp $response
