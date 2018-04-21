import java.util.Random;

Board board;
Nim nim;
UI ui;

Boolean finish = false;
Boolean help = false;
Boolean aiturn = false;
Boolean nostone = false;

int max_stone = 10;
int max_pile = 4;
int min_stone = 2;
int min_pile = 3;

int piles;
int stones[] = new int[max_stone];
int lastpile = -1;
int laststone = -1;

int game = 0;

void setup()
{
  size(1500, 1500);
  frameRate(20);
  board = new Board();
  nim = new Nim();
  ui = new UI();
  board.SetField();
}


void draw()
{
  if (aiturn && !finish) {
    nim.AI();
  }
  if (nostone && !finish) {
    ui.NoStone();
  }
  ui.YourTurn();
}


void mouseClicked()
{
   nostone = false;
  if (finish) {
    board.SetField();
    finish = false;
  } else {
    if (!aiturn)board.ChangeField(mouseX, mouseY);
  }
}

//ms ミリ秒待つ
void WaitTime(int ms)
{
  int start = millis();
  while (true) {
    int now = millis();
    if (now-start>ms)break;
  }  
  return;
}


//問題点１：連打したときに反応してしまう
//問題点２：UndoするまえにAIが石を除いてしまって変なことになる
////問題点３：AIの番の時，xorが０だと止まってしまう->解決
//問題４：「この山には石がありません」と「あなたの番です」が重複せず表示させたい
//->とりあえず一回石がない山をクリックしたら他の石をクリックするまで表示されるようにした
