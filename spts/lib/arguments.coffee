os     = require 'options-stream'
us     = require 'underscore'
path   = require 'path'
fs     = require 'fs'
Parser = require('argparse').ArgumentParser
clone  = require('clone');
version = require(process.cwd() + '/package.json').version

forkId = process.env['MY-FORK-ID'] # set forkId from ENV
cwd = process.cwd()

defaultOptions =
  user : path.relative cwd, path.normalize("#{__dirname}/../etc/config.yaml")
  config : "#{__dirname}/../etc/config.default.yaml"
Object.freeze defaultOptions # freeze me

beautifyDir = (dir) ->
  return null if dir is null
  if dir[0] is '/'
    path.relative cwd, dir
  else
    path.relative cwd, path.join cwd, dir

###
/**
 * 主web服务 命令行参数 & 配置文件解析
 * @param  {Object} options
 *  - {string} [user],   用户配置文件路径
 *  - {string} [config], 默认配置文件路径
 * @return {Object}
 *  res : 
 *   - {string} [dir],      all files dir
 *   - {string} [pretty],   url prefix for get pretty file
 *   - {string} [module],   url prefix for modules
 *   - {string} [native],   url prefix for native modules
 *   - {bool}   [watch],    watch file changed
 *   - {string} [logs_dir], logs file dir
 *  run :
 *   - {bool}   [watch],     watch file changed
 *   - {string} [logs_dir],  logs file dir
 *   - {number} [child_num], child process number
 *   - {number} [port],      listen port
 *   - {string} [sock],      listen unix domain socket
 *  proxy :
 *   - {string} [prefix],   proxy url prefix
 *   - {string} [logs_dir], logs file dir
###
module.exports = argumments = (options)->
  # set options
  {pid, config, user} = os defaultOptions, options, true

  # parser init
  parser = new Parser version: version, addHelp: true, description: 'DXP Web Server'

  # dirs & urls
  parser.addArgument [ '-d', '--dir' ],
    help: '资源文件根目录', nargs: '?'
  parser.addArgument [ '-l', '--logs-dir' ],
    help: '日志文件根目录', nargs: '?'
  parser.addArgument [ '--no-file-logs' ],
    help: '不输出日志文件', nargs: '?', action: 'count', dest : 'no_file_logs'
  parser.addArgument [ '--no-stdio-logs' ],
    help: '不输出控制台日志', nargs: '?', action: 'count', dest : 'no_logs_stdio'

  parser.addArgument [ '-n', '--native' ],
    help: 'native modules url 前缀', nargs: '?'
  parser.addArgument [ '-m', '--module' ],
    help: 'non-native module url 前缀', nargs: '?'
  parser.addArgument [ '-t', '--pretty' ],
    help: 'pretty 代码 url 前缀', nargs: '?'

  # http args
  parser.addArgument [ '-p', '--port' ],
    help: 'http 服务监听端口', nargs: '?', type:'int'
  parser.addArgument [ '-s', '--sock' ],
    help: 'http 服务监听 sock 路径', nargs: '?'
  parser.addArgument [ '-P', '--pid-file' ],
    help: "pid 文件路径", nargs: '?',
  parser.addArgument [ '--no-redis' ],
    help: "session不使用redis作为存储支持", nargs: '?', action: 'count'

  # other args
  parser.addArgument [ '-w', '--watch' ],
    help: '监听文件变更', nargs: '?', action: 'count'
  parser.addArgument [ '-W', '--no-watch' ],
    help: '不监听文件变更', nargs: '?', action: 'count'
  parser.addArgument [ '-c', '--child-num' ],
    help: '子进程数', nargs: '?', type:'int'
  parser.addArgument [ '-a', '--load-all' ],
    help: '服务启动时载入所有资源文件', nargs: '?', action: 'count'
  parser.addArgument [ '-g', '--gid' ],
    help: '进程groupid', nargs: '?', type:'int'
  parser.addArgument [ '-u', '--uid' ],
    help: '进程userid', nargs: '?', type:'int'

  # user config file
  parser.addArgument ['config_file'],
    help: "用户配置文件路径 (默认 \"%(defaultValue)s\")", nargs: '?',
    defaultValue: user


  # parse arguments
  args = parser.parseArgs()

  # remove null args
  for key, arg of args
    delete args[key] if arg is null

  # fix switch args
  for [name1, name2] in [['watch', 'no_watch']]
    args[name1] = true if args[name1] > 0
    args[name1] = false if args[name2] > 0
    delete args[name1] if args[name1] is 0 and args[name2] is 0
    delete args[name2]

  # stream config file
  if fs.existsSync args.config_file
    options = os config, args.config_file
  else
    options = os config

  # no file logs
  args.logs_dir = null if args.no_file_logs > 0
  # no stdio logs
  args.logs_stdio = not args.no_logs_stdio > 0
  # no session
  args.name = if args.no_redis > 0 then 'lru' else undefined
  # no session
  args.load_all = if args.load_all > 0 then true else undefined

  # fix options
  for k in ['res', 'stage', 'proxy']
    options[k].watch = options.watch
  for k in ['res', 'http', 'proxy', 'session', 'stage', 'auth', 'ark', 'apps', 'git']
    options[k].logs_dir = options.logs_dir
  # cache options
  for k in ['session', 'compress', 'proxy.mobilecwf', 'apidoc', 'user']
    arr = k.split '.'
    nowCache = options
    for j in arr
      nowCache = nowCache[j]
    
    base = clone options.cacheConfig
    key = (nowCache.cache && nowCache.cache.name) || base.name
    nowCache.cache = clone(os base[key], nowCache.cache)

  options.http.pid_file    = options.pid_file
  options.http.child_num   = options.child_num
  options.http.load_all    = options.load_all
  # options.vip.sock_path    = options.vip.sock

  dbServer = []
  db = options.db || {};
  for k in db.hosts
    dbServer.push({ host: k, user: db.user, password: db.password, database: db.database, port: db.port});
  # stream arguments
  opt = {
    res      : os options.res,     us.pick args, 'watch', 'dir', 'logs_dir',
      'logs_stdio', 'native', 'module', 'pretty'
    run      : os options.http,    us.pick args, 'sock', 'port', 'pid_file',
      'logs_dir', 'logs_stdio', 'child_num', 'load_all', 'gid', 'uid'
    proxy    : os options.proxy,   us.pick args, 'logs_dir', 'logs_stdio', 'watch'
    session  : os options.session, us.pick args, 'logs_dir', 'logs_stdio', 'name'
    stage    : os options.stage,   us.pick args, 'logs_dir', 'logs_stdio', 'watch'
    apps     : os options.apps,    us.pick args, 'logs_dir', 'logs_stdio'
    git      : os options.git,     us.pick args, 'logs_dir', 'logs_stdio'
    vip      : options.vip
    auth     : options.auth
    compress : options.compress
    http_header_cache : options.http_header_cache
    db       : dbServer
    ark      : options.ark
    index    : options.index
    cacheConfig: options.cacheConfig
    logs_dir : options.logs_dir
    api_doc  : options.apidoc
    user: options.user
  }
  # beautify dirs
  opt.res.dir          = beautifyDir opt.res.dir
  opt.run.pid_file     = beautifyDir opt.run.pid_file
  opt.run.sock         = beautifyDir opt.run.sock if opt.run.sock
  opt.res.logs_dir     = beautifyDir opt.res.logs_dir
  opt.run.logs_dir     = beautifyDir opt.run.logs_dir
  opt.proxy.logs_dir   = beautifyDir opt.proxy.logs_dir
  opt.session.logs_dir = beautifyDir opt.session.logs_dir
  opt.stage.logs_dir   = beautifyDir opt.stage.logs_dir
  opt.stage.cwf.html   = beautifyDir opt.stage.cwf.html
  opt.apps.logs_dir    = beautifyDir opt.apps.logs_dir
  opt.git.logs_dir     = beautifyDir opt.git.logs_dir
  opt.vip.sock         = beautifyDir opt.vip.sock
  opt

  # argumments()
