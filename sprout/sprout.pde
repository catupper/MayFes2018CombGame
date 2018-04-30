/* Aquarius 2018/04/30 */
import java.util.*;

/* TODO:
 * 線分を増やす(これないとゲームじゃない)
 * 終了判定
 *
 * 衝突判定あたりの設計の見直し
 * 判定がシビア && コーナーケースが多い
 * 新しく作った線分が元ある曲線にぶつかったらどうするの
 * せっかく Line があるので最大限に活用する
 */

/*-----------------------------*/
/*------ -  Vector2D   --------*/
/*-----------------------------*/

/* int 型の2次元ベクトル (immutable) */
class Vector2D {
	final int x;
	final int y;

	Vector2D (int x_, int y_) {
		x = x_;
		y = y_;
	}

	int x() {
		return x;
	}

	int y() {
		return y;
	}

	Vector2D add(Vector2D right) {
		return new Vector2D(x() + right.x(), y() + right.y());
	}

	Vector2D sub(Vector2D right) {
		return new Vector2D(x() - right.x(), y() - right.y());
	}

	/* 内積 */
	int dot(Vector2D right) {
		return x() * right.x() + y() * right.y();
	}

	/* 外積(2ベクトルで作る平行四辺形の面積) */
	int cross(Vector2D right) {
		return x() * right.y() - y() * right.x();
	}

	/* ノルム2乗 */
	int norm2() {
		return this.dot(this);
	}

	float norm() {
		return sqrt(norm2());
	}

	String toString() {
		return "(" + x + ", " + y + ")";
	}
}

/*-----------------------------*/
/*---------   Line   ----------*/
/*-----------------------------*/

/* 線分 (immutable) */
class Line {
	final Vector2D start;
	final Vector2D end;

	Line(Vector2D start_, Vector2D end_) {
		start = start_;
		end = end_;
	}

	Vector2D start() {
		return start;
	}

	Vector2D end() {
		return end;
	}

	String toString() {
		return "[" + start + " " + end + "]";
	}
}

/*-----------------------------*/
/*------   MathUtility   ------*/
/*-----------------------------*/

static class MathUtility {
	/* 競プロでよくあるやつ */
	static int ccw(Vector2D a, Vector2D b, Vector2D p) {
		Vector2D ab = b.sub(a);
		Vector2D ap = p.sub(a);
		if (ab.cross(ap) > 0) return 1;
		if (ab.cross(ap) < 0) return -1;
		if (ab.dot(ap) < 0) return -2;
		if (ab.norm2() < ap.norm2()) return 2;
		return 0;
	}

	/* 直線(as at) と 直線(bs bt) が交差している(端点での衝突は含まない)  */
	static boolean intersects(Vector2D as, Vector2D at, Vector2D bs, Vector2D bt) {
		return ccw(as, at, bs) * ccw(as, at, bt) < 0
		    && ccw(bs, bt, as) * ccw(bs, bt, at) < 0;
	}
}

/*-----------------------------*/
/*-----   TimerForCurve   -----*/
/*-----------------------------*/

/* 曲線を一定の長さ引くごとにそれを教えてくれるクラス */
class TimerForCurve {
	final float interval;		// 距離間隔
	double sumDistance;			// これが interval 以上になると知らせる
	Vector2D prevPosition;		// 前フレームにおける位置

	TimerForCurve(Vector2D start, float interval_) {
		interval = interval_;
		prevPosition = start;
		sumDistance = 0;
	}

	/* 毎フレーム呼び出す, 前フレームにおける位置からの距離を加算する */
	void update(Vector2D position) {
		sumDistance += prevPosition.sub(position).norm();
		prevPosition = position;
	}

	/* 一定の長さ以上になっていたら true */
	boolean elapsed() {
		boolean elapsed_ = false;
		while (sumDistance >= interval) {	 // interval の2倍以上になっていたとしても知らせるのは一度
			sumDistance -= interval;
			elapsed_ = true;
		}
		return elapsed_;
	}
}

/*-----------------------------*/
/*------   Displayable   ------*/
/*-----------------------------*/

/* 描画したいオブジェクトの基底クラス, TODO: 深度を実装 */
interface Displayable {
	void display();
}

/*-----------------------------*/
/*-------   Displayer   -------*/
/*-----------------------------*/

/* 追加された Displayable オブジェクトを描画する */
static class Displayer {
	static HashSet<Displayable> objects = new HashSet<Displayable>();

	static void update() {
		for (Displayable object : objects) {
			object.display();
		}
	}

	static void add(Displayable object) {
		objects.add(object);
	}

	static void remove(Displayable object) {
		objects.remove(object);
	}
}

/*-----------------------------*/
/*-----   DrawingTools   ------*/
/*-----------------------------*/

/* 描画する際にはこれらの関数を使うこと; static class になっていないのは processing の制限による */
class DrawingTools {
	/* 線分を描く */
	void drawLine(Vector2D from, Vector2D to, color col) {
		final int weight = 3;
		strokeWeight(weight);
		stroke(col);
		line(from.x(), from.y(), to.x(), to.y());
	}

	void drawLine(Vector2D from, Vector2D to) {
   		drawLine(from, to, color(0, 0, 0));
	}

	/* 円を描く */
	void drawCircle(Vector2D position, float radius, color col) {
		fill(col);
		noStroke();
		ellipse(position.x(), position.y(), radius * 2, radius * 2);
	}

	void drawCircle(Vector2D position, float radius) {
	   	drawCircle(position, radius, color(0, 0, 0));
	}
}

/*-----------------------------*/
/*--------   Vertex   ---------*/
/*-----------------------------*/

static final int degreeMax = 1;		// 1頂点から伸ばせる線の最大数

/* 頂点の状態 */
enum VertexState {
	Locked,		// 次数最大
	Unlocked,	// 次数にまだ余裕がある(かつマウスが乗っていない)
	MouseOver	// 次数にまだ余裕があり、マウスが乗っている
};

/* 線をつなぐための頂点 */
class Vertex implements Displayable {
	final int radius = 14;		// 円の半径(描画用)
	Vector2D position;			// 中心位置
	int degree;					// 現在この頂点から伸びている線の本数(次数)
	VertexState state;			// 状態

	Vertex(Vector2D position_) {
		position = position_;
	}

	/* 毎フレーム更新 */
	void update() {
		if (isLocked()) {
			state = VertexState.Locked;
		} else {
			if (mouseIsOver()) {
				state = VertexState.MouseOver;
			} else {
				state = VertexState.Unlocked;
			}
		}
	}

	Vector2D getPosition() {
		return position;
	}

	void display() {
		final color lockedColor = color(224, 0, 0);			// 限界次数の頂点の色
		final color unlockedColor = color(0, 0, 224);		// 次数が限界に達していない頂点の色
		final color mouseOverColor = color(112, 112, 255);	// 次数が限界に達していない頂点のマウスオーバー時の色

		switch (state) {
		case Locked:
			//drawingTools.drawCircle(position, radius, lockedColor);
			break;
		case Unlocked:
			//drawingTools.drawCircle(position, radius, unlockedColor);
			break;
		case MouseOver:
			drawingTools.drawCircle(position, radius, mouseOverColor);
			break;
		}
	}

	/* 次数の増加を外部から知らせるためのメソッド */
	void connect() {
		if (degree >= degreeMax) throw new IllegalStateException();
		++degree;
	}

	/* 次数の減少を外部から知らせるためのメソッド */
	void disconnect() {
		if (degree <= 0) throw new IllegalStateException();
		--degree;
	}

	/* 次数が上限に達しているか */
	boolean isLocked() {
		return degree >= degreeMax;
	}

	/* 点 point が頂点の上に(見た目上)存在するか */
	boolean includes(Vector2D point) {
		Vector2D diff = position.sub(point);
		return diff.norm2() <= radius * radius;
	}

	/* マウスが乗っているか */
	private boolean mouseIsOver() {
		Vector2D mousePosition = new Vector2D(mouseX, mouseY);
		return includes(mousePosition);
	}
}

/*-----------------------------*/
/*---------   Curve   ---------*/
/*-----------------------------*/

/* 固定化された曲線 */
class Curve implements Displayable {
	ArrayList<Vector2D> points;		 // 曲線の中継点 TODO: ArrayList<Line> にするといい

	Curve(ArrayList<Vector2D> points_) {
		points = points_;
	}

	/* 折れ線のセグメント数 */
	int size() {
		return points.size() - 1;
	}

	/* index 番目の線分を取得 */
	Line getSegment(int index) {
		if (index >= points.size() - 1) throw new IndexOutOfBoundsException();
		return new Line(points.get(index), points.get(index + 1));
	}

	void display() {
		for (int i = 0; i < points.size() - 1; ++i) {
			drawingTools.drawLine(points.get(i), points.get(i + 1));
		}
	}
}

/*-----------------------------*/
/*------   CurveActive   ------*/
/*-----------------------------*/

/* 描いている途中の曲線; TODO: ふつう直線と色がセットになっているものでは */
class CurveActive implements Displayable {
	ArrayList<Vector2D> points = new ArrayList<Vector2D>();	// 曲線の中継点(始点, 終点含む)
	ArrayList<Boolean> collides = new ArrayList<Boolean>();	// 各線分が他の曲線に交差しているかどうか
	TimerForCurve timer = null;

	CurveActive(Vector2D start) {
		final int interval = 12;	// 距離 interval ごとに曲線を線分に分割
		points.add(start);
		collides.add(false);
		timer = new TimerForCurve(start, interval);
	}

	/* マウスの現在位置を更新(毎フレーム実行) */
	void setCurrent(Vector2D point) {
		timer.update(point);
		if (timer.elapsed()) {		// 曲線が累計で一定の長さ以上になったときだけ点を追加
			points.add(point);
			collides.add(false);
		}
	}

	/* 直線を終端する(当たり判定の調整) */
	void terminate(Vector2D point) {
		points.add(point);
		collides.add(false);
	}

	/* Curve に変換できるかどうか(すなわち他の曲線と交差していないか) */
	boolean canBeSolidified() {
		for (boolean col : collides) {
			if (col) {
				return false;
			}
		}
		return true;
	}

	/* curve と交差しているなら collides を更新する;
	   毎フレーム, すべての曲線に対してこのメソッドを呼ぶ;
	   TODO: もうちょっといい設計ないもんかねえ */
	void collideWith(Curve curve) {
		for (int i = 0; i < points.size() - 1; ++i) {
			Vector2D as = points.get(i);
			Vector2D at = points.get(i + 1);

			for (int j = 0; j < curve.size(); ++j) {
				Line segment = curve.getSegment(j);
				Vector2D bs = segment.start();
				Vector2D bt = segment.end();
				if (MathUtility.intersects(as, at, bs, bt)) {		// 他の曲線と衝突している
					collides.set(i, true);
				}
			}
		}
	}

	/* 自分自身と交差しているなら collides を更新する;
	   毎フレームこのメソッドを呼ぶ */
	void collideWithItself() {
		for (int i = 0; i < points.size() - 1; ++i) {
			Vector2D as = points.get(i);
			Vector2D at = points.get(i + 1);

			for (int j = 0; j < points.size() - 1; ++j) {
				if (abs(i - j) <= 1) continue;		// 隣接する線分が衝突しているのは当然なので飛ばす

				Vector2D bs = points.get(j);
				Vector2D bt = points.get(j + 1);
				if (MathUtility.intersects(as, at, bs, bt)) {	// 自分自身と衝突している
					collides.set(i, true);
				}
			}
		}
	}

	/* CurveActive を Curve に変換する(コード内ではこの意味で動詞 'solidify' を使うことにする) */
	Curve solidify(Vector2D end) {
		if (!canBeSolidified()) throw new IllegalStateException();
		points.add(end);
		return new Curve(points);
	}

	void display() {
		final color colorOk = color(128, 128, 128);		// デフォルトの色
		final color colorNg = color(224, 0, 0);			// 交差している部分の色

		for (int i = 0; i < points.size() - 1; ++i) {
			color curveColor;
			if (collides.get(i)) {
				curveColor = colorNg;
			} else {
				curveColor = colorOk;
			}

			drawingTools.drawLine(points.get(i), points.get(i + 1), curveColor);
		}
	}
}

/*-----------------------------*/
/*---------   Field   ---------*/
/*-----------------------------*/

/* フィールド,
  TODO: 現在は Field クラスが線を作っていたりと「フィールド」の役割を超えることをしているが、
  		あとでその名の通り public Field としての役割に限定する */
class Field {
	ArrayList<Vertex> vertices = new ArrayList<Vertex>();		// 頂点の集合
	ArrayList<Curve> curves = new ArrayList<Curve>();			// 直線の集合
	CurveActive curveActive = null;		// 描き途中の曲線
	Vertex startSelected = null;		// curveActive の始点
	Vertex endSelected = null;			// curveActive の終点


	/* 頂点を追加 */
	void addVertex(Vector2D position) {
		Vertex vertex = new Vertex(position);
		vertices.add(vertex);
		Displayer.add(vertex);
	}

	/* 曲線を追加(追加時には交差判定は行われない) */
	void addCurve(ArrayList<Vector2D> points) {
		Curve curve = new Curve(points);
		curves.add(curve);
		Displayer.add(curve);
	}

	void update() {
		Vector2D position = new Vector2D(mouseX, mouseY);
		for (Vertex vertex : vertices) {
			/* 各頂点を更新 */
			vertex.update();
		}

		/* curveActive が存在するなら交差判定をする */
		if (curveActive != null) {
			curveActive.collideWithItself();
			for (Curve curve : curves) {
				curveActive.collideWith(curve);
			}
		}
	}

	/* 新しい直線を描き始める */
	void startDrawing(Vector2D position) {
		startSelected = fetchVertex(position);		//クリックした場所にある頂点を取ってくる
		if (startSelected == null) return;
		Vector2D start = startSelected.getPosition();

		curveActive = new CurveActive(start);		// その頂点から直線を引き始める
		Displayer.add(curveActive);

		startSelected.connect();					// 頂点の次数を増やす
	}

	/* ドラッグ中, TODO: メソッド名なんやねん */
	void drag(Vector2D position) {
		if (curveActive == null) return;
		curveActive.setCurrent(position);		// 描き途中の直線を更新
	}

	/* 直線を描き終える; TODO: 明らかにややこしすぎる */
	void endDrawing(Vector2D position) {
		if (curveActive == null) return;		// そもそも curveActive がないなら終了

		endSelected = fetchVertex(position);	// 終点にある頂点を取ってくる
		startSelected.disconnect();				// いったん始点の接続を切っておく

		/* もし頂点が存在したなら */
		if (endSelected != null) {
			Vector2D end = endSelected.getPosition();
			curveActive.terminate(end); 		// 頂点の座標で終端する(当たり判定に抜けが出ないように)

			/* TODO: ここで衝突判定するの絶対おかしいんだよなあ */
			curveActive.collideWithItself();
			for (Curve curve : curves) {
				curveActive.collideWith(curve);
			}

			/* 他の曲線と交差していなければ curveActive を solidify する */
			if (curveActive.canBeSolidified()) {
				Curve curve = curveActive.solidify(end);
				curves.add(curve);
				Displayer.add(curve);

				/* 両端点を接続 */
				startSelected.connect();
				endSelected.connect();
			}
		}

		/* curveActive を消去 */
		Displayer.remove(curveActive);
		curveActive = null;
		startSelected = null;
		endSelected = null;
	}

	/* position に存在する頂点を(高々1つ)返す; なければ null を返す */
	private Vertex fetchVertex(Vector2D position) {
		for (Vertex vertex : vertices) {
			if (vertex.isLocked()) continue;		// 次数限界の点は選ばない
			if (vertex.includes(position)) {
				return vertex;
			}
		}
		return null;
	}
}

/*-----------------------------*/
/*------   GameManager   ------*/
/*-----------------------------*/

/* ゲーム全体をつかさどる(TODO: ほんまか?) */
class GameManager {
	Field field = new Field();
	ArrayList<Vector2D> markerPositions = new ArrayList<Vector2D>();	// 十字型マーカーの位置

	/* 十字型マーカーの位置を決める */
	void decideMarkerPositions() {
		Vector2D center = new Vector2D(width / 2, height / 2);		// 中心
		Vector2D circle = new Vector2D(width / 3, height / 3);		// 楕円半径
		final int markerMax = 5;		// マーカー数
		final int uncertainty = 30;		// ゆらぎ

		for (int i = 0; i < markerMax; ++i) {
			Vector2D diff = new Vector2D(
				(int)(circle.x() * cos(TWO_PI * i / markerMax - HALF_PI)),
				(int)(circle.y() * sin(TWO_PI * i / markerMax - HALF_PI))
			);
			Vector2D rand = new Vector2D(
				(int)random(-uncertainty, uncertainty),
				(int)random(-uncertainty, uncertainty)
			);

			Vector2D position = center.add(diff).add(rand);
			markerPositions.add(position);
		}
	}

	/* 十字型マーカーを Field に配置する */
	void locateMarkers() {
		final int radius = 30;		// マーカーの大きさ

		for (Vector2D markerPosition : markerPositions) {
			Vector2D left   = markerPosition.add(new Vector2D(-radius, 0));
			Vector2D right  = markerPosition.add(new Vector2D(radius, 0));
			Vector2D top    = markerPosition.add(new Vector2D(0, -radius));
			Vector2D bottom = markerPosition.add(new Vector2D(0, radius));

			field.addVertex(left);
			field.addVertex(right);
			field.addVertex(top);
			field.addVertex(bottom);

			ArrayList<Vector2D> vertical = new ArrayList<Vector2D>(Arrays.asList(left, right));
			ArrayList<Vector2D> horizontal = new ArrayList<Vector2D>(Arrays.asList(top, bottom));
			field.addCurve(vertical);
			field.addCurve(horizontal);
		}
	}

	/* ゲームの初期化 */
	void initialize() {
		decideMarkerPositions();
		locateMarkers();
	}

	/* 毎フレーム更新(press, release はこれとは別に割り込みで判定) */
	void update() {
		if (mousePressed) {
			Vector2D mousePosition = new Vector2D(mouseX, mouseY);
			field.drag(mousePosition);
		}
		field.update();
	}

	/* マウスが押された瞬間 */
	void mouseIsPressed(Vector2D position) {
		field.startDrawing(position);
	}

	/* マウスが話された瞬間 */
	void mouseIsReleased(Vector2D position) {
		field.endDrawing(position);
	}
}

/*-----------------------------*/
/*--------   Global   ---------*/
/*-----------------------------*/

/* デバッグ用 */
class Printf implements Displayable {
	String str = new String();

	void set(String str_) {
		str = str_;
	}

	void display() {
		text(str, 50, 50);
	}
}

/* GameManager */
GameManager gameManager = new GameManager();

/* static class にできないためにグローバルにおいている変数 */
Printf printf = new Printf();
DrawingTools drawingTools = new DrawingTools();

void setup() {
	size(1280, 960);
	colorMode(RGB, 256);		// RGB 256 階調で色設定を与える

	/* 初期化 */
	gameManager.initialize();
	Displayer.add(printf);
}

void draw() {
	background(color(255, 255, 255));

	gameManager.update();
	Displayer.update();
}

void mousePressed() {
	Vector2D mousePosition = new Vector2D(mouseX, mouseY);
	gameManager.mouseIsPressed(mousePosition);
}

void mouseReleased() {
	Vector2D mousePosition = new Vector2D(mouseX, mouseY);
	gameManager.mouseIsReleased(mousePosition);
}
