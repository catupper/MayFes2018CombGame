/*-----------------------------*/
/*------ -  Vector2D   --------*/
/*-----------------------------*/

/* int 型の2次元ベクトル (immutable) */
static class Vector2D {
	final int x;
	final int y;

	Vector2D(int x_, int y_) {
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

	Vector2D mul(float scalar) {
		return new Vector2D((int)(x() * scalar), (int)(y() * scalar));
	}

	Vector2D div(float scalar) {
		return new Vector2D((int)(x() / scalar), (int)(y() / scalar));
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

	/* 偏角 */
	double arg() {
		double arg = atan2(y, x);
		if (arg < 0) arg += TWO_PI;
		return arg;
	}

	boolean equals(Object obj) {
		if (!(obj instanceof Vector2D)) return false;

		Vector2D other = (Vector2D)obj;
		return x == other.x && y == other.y;
	}

	int hashCode() {
		return Objects.hash(x, y);
	}

	String toString() {
		return "(" + x + ", " + y + ")";
	}
}

/*-----------------------------*/
/*--------   Segment   --------*/
/*-----------------------------*/

/* 線分 (immutable) */
static class Segment {
	final Vector2D start;
	final Vector2D end;

	Segment(Vector2D start_, Vector2D end_) {
		start = start_;
		end = end_;
	}

	Vector2D start() {
		return start;
	}

	Vector2D end() {
		return end;
	}

	/* 長さの2乗 */
	int length2() {
		return end.sub(start).norm2();
	}

	boolean includes(Vector2D point) {
		return MathUtility.ccw(start, end, point) == 0;
	}

	boolean includes(Segment other) {
		return includes(other.start) && includes(other.end);
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

	/* 2つの線分が交差しているかどうか(端点での衝突は含まない)  */
	static boolean intersects(Segment a, Segment b) {
		return ccw(a.start(), a.end(), b.start()) * ccw(a.start(), a.end(), b.end()) < 0
			&& ccw(b.start(), b.end(), a.start()) * ccw(b.start(), b.end(), a.end()) < 0;
	}

	/* 2つの直線の交点(なくても無理やり返す); 交点座標は(分数になることもあるが)整数に丸める  */
	static Vector2D intersectionPoint(Segment a, Segment b) {
		Vector2D p = a.start();
		Vector2D q = a.end();
		Vector2D r = b.start();
		Vector2D s = b.end();

		Vector2D vec_a = new Vector2D(p.y() - q.y(), r.y() - s.y());
		Vector2D vec_b = new Vector2D(q.x() - p.x(), s.x() - r.x());
		Vector2D vec_c = new Vector2D(p.cross(q), r.cross(s));
		int det = vec_a.cross(vec_b);

		if (det == 0) return p;  	// 2つの直線が平行のとき: 適当に返しておく
		return new Vector2D(vec_b.cross(vec_c) / det, vec_c.cross(vec_a) / det);
	}

	/* from → center → to と進む折れ線のなす角; [0, 2PI) */
	static double angle(Vector2D from, Vector2D center, Vector2D to) {
		double angle = to.sub(center).arg() - from.sub(center).arg();
		if (angle < 0) angle += TWO_PI;
		return angle;
	}
}


class DebugLine implements Displayable {
	final Segment seg;
	DebugLine(Segment seg_) {
		seg = seg_;
		Displayer.add(this, 1);
	}

	void display() {
		drawingTools.drawLineForDebug(seg);
	}
}

/*-----------------------------*/
/*---------   Graph   ---------*/
/*-----------------------------*/

/* コスト付きグラフ */
static class Graph {
	static class Element {
		final int from;
		final int to;
		final int cost;

		Element(int from_, int to_, int cost_) {
			from = from_;
			to = to_;
			cost = cost_;
		}

		Element(int from_, int to_) {
			this(from_, to_, 1);
		}

		int from() {
			return from;
		}

		int to() {
			return to;
		}

		int cost() {
			return cost;
		}

		String toString() {
			return "(" + from + ", " + to + ", " + cost + ")";
		}
	}

	List<List<Element>> list;

	Graph() {
		list = new ArrayList<List<Element>>();
	}

	Graph(int size) {
		list = new ArrayList<List<Element>>(size);
		for (int i = 0; i < size; ++i) {
			list.add(new ArrayList<Element>());
		}
	}

	Graph(Graph other) {
		list = new ArrayList<List<Element>>(other.size());
		for (int i = 0; i < other.size(); ++i) {
			list.add(new ArrayList<Element>(other.list.get(i)));
		}
	}

	private boolean isValidIndex(int index) {
		return index >= 0 && index < size();
	}

	void add(int from, int to, int cost) {
		if (!isValidIndex(from)) throw new IndexOutOfBoundsException();
		if (!isValidIndex(to)) throw new IndexOutOfBoundsException();

		Element element = new Element(from, to, cost);
		list.get(from).add(element);
	}

	void add(int from, int to) {
		add(from, to, 1);
	}

	Iterator<Element> getIterator(int from) {
		return list.get(from).iterator();
	}

	int size() {
		return list.size();
	}

	void resize(int newSize) {
		if (newSize < size()) throw new IllegalArgumentException();
		for (int i = size(); i < newSize; ++i) {
			list.add(new ArrayList<Element>());
		}
	}

	String toString() {
		StringBuilder builder = new StringBuilder();
		for (int from = 0; from < size(); ++from) {
			builder.append("[" + from + "]: {");
			for (Element element : list.get(from)) {
				builder.append(" " + element.toString());
			}
			builder.append(" }\n");
		}
		return builder.toString();
	}
}
