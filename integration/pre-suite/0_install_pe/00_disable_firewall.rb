test_name 'Disable firewall'
confine :to, :platform => 'el-7-x86_64'

on(master, 'systemctl stop firewalld')
