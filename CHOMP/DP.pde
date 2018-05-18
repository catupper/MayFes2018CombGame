int[] dpx = new int[1<<22];
int[] dpy = new int[1<<22];
int[] win = new int[1<<22];
int[] cntbit = new int[1<<22];
void initDp(){
  for(int i = 0;i < (1 << 22);i++){
    win[i] = -1;
    dpx[i] = -1;
    dpy[i] = -1;
    if(i == 0)cntbit[i] = 0;
    else cntbit[i] = cntbit[i/2] + i%2;
  }
  for(int i = 0;i < (1<<22);i++){
    if(cntbit[i] != 10)continue;
    find(i);
  }
}

int[] decreaseDim(int [][] field){
  int[] res = new int[10];
  for(int i = 0;i < 10;i++){
    for(int j = 0;j < 12;j++){
      if(field[i][j] > 0)res[i]++;
    }
  }
  return res;
}

int[] ConvertToArray(int val){
    int[] res = new int[10];
    int now = 0;
    int valu = 12;
    for(int i = 0;i < 22;i++){
      if(val % 2 == 0)valu--;
      else {res[now++] = valu;}
      val /= 2;
    }
    return res;
}

int convertToVal(int[] array){
  int now = 9;
  int val = 0;
  int res = 0;
  for(int i = 0;i < 22;i++){
    res *= 2;
    if(now >= 0 && val == array[now]){
      res++;
      now--;
    }  
    else{
      val++;
    }
  }
  return res;
}

int[] tryField(int[] field, int x, int y){
  int[] res = new int[10];
  for(int i = 0;i < 10;i++)res[i] = field[i];
  for(int i = x;i < 10;i++){
    res[i] = min(res[i], y);
  }
  return res;
}

int find(int val){
  int[] field = ConvertToArray(val);
  int val2 = convertToVal(field);
  //println(val, val2);
  if(win[val] != -1)return win[val];
  if(field[0] == 0){
    return win[val] = 1;
  }
  for(int i = 0;i < 10;i++){
    for(int j = 0;j < field[i];j++){
       if(find(convertToVal(tryField(field, i, j))) == 0){
         dpx[val] = i;
         dpy[val] = j;
         return win[val] = 1;
       }
    }
  }
  return win[val] = 0;
}
