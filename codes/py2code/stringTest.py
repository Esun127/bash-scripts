
#coding:utf-8

ch_numbers = [' ', '一', '二', '三', '四', '五', '六', '七', '八', '九', '零']

numbers = [' ', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0']


import string
import random

# for i in range(1,10):
#     for j in range(1, i+1):
        # plus = i * j
        # if plus >= 10:
        #     left = ch_numbers[numbers.index(str(plus).ljust(2)[0])]
        #     right = ch_numbers[numbers.index(str(plus).rjust(2)[1])]
        #     ji = left + right
        # else:
        #     ji = ch_numbers[plus]

        
        # print(left, right)
        # print(ch_numbers[numbers.index(str(i))], ch_numbers[numbers.index(str(j))] , ji,  end=', ')


    ### 方法二
        # left = ch_numbers[numbers.index(str(j*i).ljust(2)[0])]
        # right = ch_numbers[numbers.index(str(j*i).ljust(2)[1])]
        # print(f'{ch_numbers[j]}*{ch_numbers[i]}={left}{right}',end=' ')
    # print()





strfrom = string.ascii_letters+string.digits
print(''.join([random.choice(strfrom) for _ in range(10)]))