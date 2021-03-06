mongoose = require 'mongoose'

exports.requiredLogined = (req, res, next) ->
  if req.session && req.session.user
    next()
  else
    if req.xhr
      res.json { success: 0, message: "please_signin" }
    else
      req.flash 'notices', ["请登录"]
      if req.header 'Referer'
        res.redirect "/login?next=#{req.path}"
      else
        res.redirect "/login"


exports.notifications = (req, res, next) ->
  if req.session && req.session.user
    user_id = req.session.user._id
    Notification = mongoose.model 'Notification'
    Notification.unreadCount user_id, (err, count) ->
      throw err if err
      res.locals.notification_count = count
      next()
  else
    next()

exports.csrf = (req, res, next) ->
  res.locals.csrf_token = req.session._csrf
  next()

