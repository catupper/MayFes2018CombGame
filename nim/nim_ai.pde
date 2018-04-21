class Nim
{
  void AI()
  {
    int res = xor();

    if (res==0)RandomOperation();
    else {
      if (millis()%5==0)RandomOperation();
      else IntelligentOperation(res);
    }
    WaitTime(1000);
    board.PutStones();
    aiturn = false;
  }

  void IntelligentOperation(int res)
  {
    String res_bin = Integer.toBinaryString(res);

    for (int i=0; i<piles; i++) {
      String ith_pile_bin = Integer.toBinaryString(stones[i]);

      if (ith_pile_bin.length()>=res_bin.length()) {
        if (ith_pile_bin.charAt(ith_pile_bin.length()-res_bin.length())=='1') {

          int k = ith_pile_bin.length()-res_bin.length();
          String str = ith_pile_bin.substring(0, k);

          for (int j = k; j < ith_pile_bin.length(); j++) {
            if (res_bin.charAt(j-k)=='1') {

              if (ith_pile_bin.charAt(j) == '0')str+='1';
              else str+='0';
            } else {
              str += ith_pile_bin.charAt(j);
            }
          }

          stones[i]=Integer.parseInt(str, 2);
          break;
        }
      }
    }
  }

  void RandomOperation()
  {
    int selectable_piles[] = new int[max_pile];

    int cnt=0;
    for (int i=0; i<piles; i++) {
      if (stones[i]!=0) {
        selectable_piles[cnt]=i;
        cnt++;
      }
    }

    Random rnd;
    rnd = new Random();
    int selected_pile = selectable_piles[rnd.nextInt(cnt)];
    int new_stones = rnd.nextInt(stones[selected_pile]);
    stones[selected_pile]=new_stones;
  }

  int xor()
  {
    int res = 0;
    for (int i=0; i<piles; i++) {
      res^=stones[i];
    }
    return res;
  }
}
