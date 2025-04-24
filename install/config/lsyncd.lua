settings {
  logfile = os.getenv("LSYNCD_LOGFILE") or "/tmp/lsyncd.log",
  statusFile = "/tmp/lsyncd.status",
  inotifyMode = "CloseWrite or Modify",
  maxProcesses = 2,
}
targets = {
  os.getenv("LSYNCD_TARGET"),
}
for _, target in ipairs( targets )
do
sync {
  default.rsync,
  source = "/var/www/html/" .. os.getenv("DRUPAL_WEB_ROOT"),
  target = target,
  maxDelays = 5,
  delay = 3,
  delete = true,
  exclude = {
    '*.log',
    'vendor',
    'tests',
    '.DS_Store',
    '.*',
    '*.patch',
    'README.*',
    'config',
    'patches',
    'Dockerfile',
    '*.module',
    '*.XXXXXX',
    '*.po',
    '*.yml',
    '*.yaml',
    '*.twig',
    '*.theme',
    '*.phar',
    '*.md',
    "*.php",
    '.git',
    '*.inc',
    '*.install',
    '*.json',
    '*.lock',
    'tmp-*',
    '*.sql',
    '*.tgz',
    '*.sh',
  },
  rsync = {
    binary = "/usr/bin/rsync",
    archive = true,
    compress = true,
    bwlimit = 20000,
    rsh = "sshpass -p " .. os.getenv("LSYNCD_TARGET_PASSWORD") .. " ssh -p " .. os.getenv("LSYNCD_TARGET_PORT") .. " -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
  }
}
end