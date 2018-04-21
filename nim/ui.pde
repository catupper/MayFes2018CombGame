class UI
{
  float tatehaba = height/(max_stone+3);

  //ひとつ前の状態に戻る
  void Undo()
  {
    if (aiturn)return;
    if (lastpile!=-1&&laststone!=-1) {
      stones[lastpile] = laststone;
    }
    board.PutStones();
    aiturn = false;
  }

  void Help()
  {
    background(255);

    PFont font = createFont("MS Gothic", width/20, true);
    textFont(font);
    textAlign(CENTER);

    String str = "石をクリックすると\n";
    str += "その石自身と上に積まれている石を\n";
    str += "取り除けます\n";
    //str += "もし間違えてしまったときは\n";
    //str += "Undoボタンを押すことで元に戻れます\n\n";
    str += "クリックするとゲーム画面に戻ります\n";

    text(str, width/2, height/3);
  }

  void YourTurn()
  {
    if (!aiturn && !finish && !nostone && !help) {
      PFont font = createFont("MS Gothic", tatehaba*0.6, true);
      textFont(font);
      textAlign(CENTER);
      fill(255, 100, 0);
      text("あなたの番です", width/2, tatehaba);
    }
  }

  void NoStone()
  {
    board.PutStones();
    PFont font = createFont("MS Gothic", tatehaba*0.6, true);
    textFont(font);
    textAlign(CENTER);
    fill(255, 100, 0);
    text("この山に石はありません", width/2, tatehaba);
  }
}
