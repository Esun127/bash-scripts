
from optparse import OptionParser
from copy import copy
from optparse import Option, OptionValueError
import subprocess
import os
import yaml

#  自定义类型
def check_tuple(option, opt, value):
    # print(option, opt, value)
    try:
        return tuple(value.split(','))
    except ValueError:
        raise OptionValueError(
            "option %s: invalid tuple value: %r" % (opt, value))

class MyOption(Option):
    TYPES = Option.TYPES + ("tuple",)
    TYPE_CHECKER = copy(Option.TYPE_CHECKER)
    TYPE_CHECKER["tuple"] = check_tuple



# 参数设计
def argumentSet():

    usage = '''
        usage: %prog  -W/--web host,username,password 
                        -T/--tserver host,username,password 
                        -D/--db host,username,password
                        -d baibaoyun.com
                        -s pub,admin,api
                        -p /path/to/baibaoyun.pem
                        -k /path/to/baibaoyun.key
                        /path/to/bby
    '''

    parser = OptionParser(option_class=MyOption, usage=usage)
    parser.add_option("-W", "--web", 
                        dest="web", action="append", type="tuple",
                    help="传入WEB角色群参数", metavar="host,username,password")
    parser.add_option("-T", "--tserver",
                    dest="tserver", action="append", type="tuple",
                        metavar="host,username,password",
                    help="传入cloudserver角色群参数")
    parser.add_option(
                        "-D", "--db",
                        dest="db", action="store", type="tuple",
                        metavar="host,username,password",
                        help="传入DB角色参数"
                    )
    parser.add_option("-p", "--pem", dest="pempath", metavar="/path/to/baibaoyun.pem", default="cert/baibaoyun.pem", help="指定baibaoyun.pem的路径")
    parser.add_option("-k", "--key", dest="keypath", metavar="/path/to/baibaoyun.key", default="cert/baibaoyun.key", help="指定baibaoyun.key的路径")
    parser.add_option("-d", "--domain", metavar="baibaoyun.com", help="指定主域名")
    parser.add_option("-s", "--subdomian", metavar="pub,admin,api", type="tuple", help="指定二级域名列表")

    return parser.parse_args()
    

# print(options)

# 解析参数执行剧本
def execansible(options, args):
    with open(args + "/hosts", 'w') as f:
        keylist=['web', 'db', 'tserver']
        for k in keylist:
            if hasattr(options, k):
                vlist=getattr(options, k)
                if vlist:
                    # print(vlist)
                    f.write('['+k+']\n')
                    if isinstance(vlist, list):
                        for h in vlist:
                            print(h)
                            s = h[0] + '\t' + 'ansible_ssh_user=' + h[1] +'\tansible_ssh_pass=' + h[2] + '\n' 
                            f.write(s)         
                    elif isinstance(vlist, tuple):
                        s = vlist[0] + '\t' + 'ansible_ssh_user=' + vlist[1] +'\tansible_ssh_pass=' + vlist[2] + '\n'
                        f.write(s)
                    else:
                        raise ValueError(k + "传递的参数格式有误")

                    
                else:
                    raise ValueError('未传入参数' + k)


    p=subprocess.Popen("ansible-playbook -i hosts site.yaml", stdin=subprocess.PIPE, stdout=subprocess.PIPE, shell=True, cwd=args)
    o, e = p.communicate()
    if not e:
        print(o)
    else:
        print(e)
        

# 解析参数更新group_vars/all
def updateconfig(options, args):

    
    with open(os.path.join(args, 'group_vars/all.template'), 'r') as f:
        conf = yaml.load(f)

    if options.pempath:
        conf['pemPath'] = options.pempath
    if options.keypath:
        conf['keyPath'] = options.keypath

    if not options.domain:
        raise ValueError("必须设置参数" + 'domain' )
    if not ( options.subdomian and isinstance(options.subdomain, tuple):
        raise ValueError("必须设置参数" + 'subdomain' +  ', 且格式为pub,admin,api')

    conf['domain_name'] = options.domain
    conf['subdomain'] = list(options.subdomain)

    with open(os.path.join(args, 'group_vars/all.template'), 'w') as f:
        yaml.dump(conf, f, default_flow_style=False)



        







if __name__ == "__main__":
    options, args = argumentSet()
    if len(args) != 1:
        raise ValueError("需要设置ansible_bby的绝对路径")
    print(options)
    