import argparse
import sys


# args_list = sys.argv[1:]
# print(args_list)


inventories= {}

# 创建参数解析器
parser = argparse.ArgumentParser(description='根据命令行参数生成ansible的动态资产文件.')


# parser.add_argument('integers', metavar='N', type=str, nargs='+',
#                     help='an integer for the accumulator')

parser.add_argument('-W', '--web', nargs=3, dest='webs', type=str,
                    required=True, metavar='host username password',
                    help='传入WEB角色群参数')
# parser.add_argument('-C', '--cloud', nargs='3', metavar='host,username,password',
#                     required=True, dest='clouds',
#                     help='传入cloudserver角色群参数')                   
# parser.add_argument('-D', '--db',  metavar='host,username,password',
#                     required=True, dest='db',
#                     help='传入DB角色参数')

args = parser.parse_args()
print(args.webs)
