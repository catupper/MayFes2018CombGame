class Board
{
  float tatehaba = height/(max_stone+3);

  //石を置く
  void PutStones()
  {   
    background(255);

    float yokohaba = width/piles;
    float hankei = height/max_stone * 0.4;

    //線を引く
    line(0, tatehaba*2, width, tatehaba*2);
    textSize(tatehaba*0.6);
    textAlign(LEFT);
    fill(0);

    //Help,Undoの表示
    text("Help", 0, tatehaba*2);
    //textAlign(RIGHT);
    //text("Undo",width,tatehaba*2);
    textAlign(CENTER);

    text(nim.xor(), width/2, tatehaba*2);


    //石を配置
    int all = 0;
    for (int i=0; i<piles; i++) {
      float yoko = yokohaba*(i+0.5);
      for (int j=0; j<stones[i]; j++) {
        float tate = height - tatehaba*(j+1);
        ellipse(yoko, tate, hankei, hankei);
        all++;
      }
    }
    if (all == 0) {
      Finish();
    }
  }

  void Finish()
  {
    finish = true;
    background(255);
    textSize(width/15);
    textAlign(CENTER);
    if (aiturn == true) {
      text("You Lose!", width/2, height/2);
    } else {
      text("You Win!", width/2, height/2);
    }
  }

  //初期配置
  void SetField()
  {
    Random rnd = new Random();

    //山の数を乱数で決定
    piles = rnd.nextInt(max_pile-min_pile+1)+min_pile;

    //各山の石の数も乱数で決定 
    for (int i=0; i<piles; i++) {
      stones[i] = rnd.nextInt(max_stone-min_stone+1)+min_stone;
    }  
    PutStones();
    finish = false;
    if (game%2==0)aiturn = false;
    else aiturn = true;
  }

  //クリックされたとき
  void ChangeField(float x, float y)
  {
    //現在ヘルプ画面なら元に戻す

    if (help) {
      PutStones();
      help = false;
    } else {
      if (y<=tatehaba*2) {
        if (x<=width/2) {
          ui.Help();
          help = true;
        }
        //else{
        //  Undo();
        //}
      } else {
        float yokohaba = width/piles;
        int checkpile = floor(x/yokohaba);
        if (stones[checkpile] == 0) {
          nostone = true;
        } else {
          RemoveStone(checkpile, y);
        }
      }
    }
  }

  //クリックされた石とその上の石を取り除く
  void RemoveStone(int checkpile, float y)
  { 
    //どの石か
    float mn = 999999;
    int clickedstone = -1;
    for (int i=0; i<stones[checkpile]; i++) {
      float stone_y = height - tatehaba*(i+1);
      float dist = abs(y-stone_y);
      if (dist<mn) {
        mn=dist;
        clickedstone = i;
      }
    }

    //ひとつ前の状態を記録しておく
    lastpile = checkpile;
    laststone = stones[checkpile];

    //石の数更新
    stones[checkpile] = clickedstone;

    PutStones();
    aiturn = true;
  }
}
