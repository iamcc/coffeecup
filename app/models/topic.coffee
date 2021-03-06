mongoose = require 'mongoose'
async = require 'async'
lib = require './lib'
# settings = require("../../config/settings")(process.env.NODE_ENV or 'development')

Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

topicSchema = new mongoose.Schema
  user_id: { type: ObjectId, required: true, index: true }
  node_id: { type: ObjectId, required: true , index: true }
  title: { type: String, required: true }
  content: { type: String }
  content_html: { type: String }
  # username: { type: String } # for cache
  hit: { type: Number, default: 0}
  vote_users: [{ type: ObjectId, ref: "User" }]
  replies_count: { type: Number, default: 0}
  last_replied_by: String
  last_replied_at: { type: Date, default: Date.now}
  created_at: { type: Date, default: Date.now }
  updated_at: { type: Date, default: Date.now }

# 获取 topic 列表, 并获取 user 和 node 信息
# 参数 conditions:查询条件, options: 选项, callback:回调
topicSchema.statics.getTopicListWithNodeUser = (conditions, options, callback) ->
  fields= 'user_id node_id title replies_count last_replied_by created_at'
  @find conditions, fields, options, (err, topics) ->
    return callback err if err
    async.waterfall [
      (next) ->
        async.map topics, getUser, (err, results) ->
          return next err if err
          next null, results
      (topics, next) ->
        async.map topics, getNode, (err, results) ->
          return next err if err
          next null, results
    ],
    (err, results) ->
      return callback err if err
      callback null, results

# 通过 node_id 获取 topic 列表 
# 并获取 topic 用户信息, ex: node/show 页面
topicSchema.statics.getTopicListWithUser = (node_id, count, callback) ->
  fields= 'user_id node_id title replies_count last_replied_by created_at'
  options = 
    limit: count
    sort: last_replied_at: -1
  @find {node_id: node_id}, fields, options, (err, topics) ->
    async.map topics, getUser, (err, results) ->
      return callback err if err
      callback null, topics

# 通过 user_id 获取 topic 列表
# 并获取 topic 节点信息 ex: user/topic 页面
topicSchema.statics.getTopicListWithNode = (user_id, limit, skip, callback) ->
  fields= 'user_id node_id title replies_count last_replied_by created_at'
  options = 
    limit: limit
    sort: created_at: -1
    skip: skip
  @find {user_id: user_id}, fields, options, (err, topics) ->
    async.map topics, getNode, (err, results) ->
      return callback err if err
      callback null, results

getUser = (topic, callback) ->
  User = mongoose.model 'User'
  fields = 'username reg_id gravatar_type email_md5'
  User.findById topic.user_id, fields, (err, user) ->
    return callback err if err
    topic.user = user
    callback null, topic

getNode = (topic, callback) ->
  Node = mongoose.model 'Node'
  fields = 'name key'
  Node.findById topic.node_id, fields, (err, node) ->
    return callback err if err
    topic.node = node
    callback null, topic

# 获取用户的id, async map中迭代用
getUserIdByUsername = (username, callback) ->
  User = mongoose.model 'User'
  User.findOne(username: username).select('_id').exec (err, user) ->
    return callback err if err
    return callback null, null unless user
    callback null, user.id

# 获取topic提到的用户id，返回数组
topicSchema.methods.getMentionUserIds = (callback) ->
  usernames = lib.findMentionUsers(@content)
  async.map usernames, getUserIdByUsername, (err, ids) ->
    return callback err if err
    callback null, ids

# async each 发送提醒
# replySchema.methods.sendNotification = (who, callback) ->
# 将reply实例context绑定
sendNotification = (who, callback) ->
  # user 不存在
  return callback null unless who
  # 排除自己
  return callback null if who.toString() == @user_id.toString()

  Notification = mongoose.model 'Notification'
  notification = new Notification
    user_id: who
    notifiable_id: @id
    action: 'topic_mention'
    action_user_id: @user_id
    content: @content_html

  notification.save (err, doc) ->
    return callback err if err
    callback null
 
# 文中提到的人发提醒
topicSchema.methods.sendMentionNotification = (user_ids, callback) ->
  topic = @
  async.each user_ids, sendNotification.bind(topic), (err) ->
    return callback err if err
    return callback null

# topicSchema.methods.node = (callback) ->
#   Node = mongoose.model 'Node'
#   Node.findById @node_id, (err, node) ->
#     return callback err if err
#     callback null, node

topicSchema.pre 'save', (next) ->
  @updated_at = new Date()
  if @isModified 'content'
    @content_html = lib.topicToHtml @content
  next()

mongoose.model 'Topic', topicSchema
