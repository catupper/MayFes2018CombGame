int Width = 600, Height = 600;

int mode;
int count;

void setup(){
  game = new Board(10,12,100, 100);
  mode = 0;
  size(1000, 1000);
}

void draw(){
  background(255, 255, 255);
  println(mode);
  println("hoge");
  if(mode == 0){
    game.draw_turn();
    game.hover(mouseX, mouseY);
    game.drawField();
  }
  else if(mode == 1){
    game.draw_turn();
    count--;
    if(count < 0){
      println(count);
      count = 0;
      mode = 0;
      game.AI();
      if(game.check_game_over() == 1){
        game.game_over();
        mode = 2;
        count = 300;
      }
      else game.change_turn();
    }
    game.drawField();
  }
  else if(mode == 2){
    count--;
    if(count < 0){
      count = 0;
      mode = 0;
      game.reset();
    }
    game.game_over();
  }
}

void mouseClicked(){
  if(game.turn != 0)return;
  int turned = game.select(mouseX, mouseY);
  if(game.check_game_over() == 1){
    game.game_over();
    mode = 2;
    count = 300;
  }
  else if(turned == 1){
    game.change_turn();
    mode = 1;
    count = 100; 
  }
}