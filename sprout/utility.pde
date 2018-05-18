import java.math.BigInteger;

/*-----------------------------*/
/*--------  Rational   --------*/
/*-----------------------------*/

static class Rational implements Comparable<Rational> {
	final BigInteger numer;
	final BigInteger denom;

	static final Rational ZERO = new Rational(0);

	Rational(int integer) {
		this(integer, 1);
	}

	Rational(int numer_, int denom_) {
		this(BigInteger.valueOf(numer_), BigInteger.valueOf(denom_));
	}

	Rational(BigInteger numer_, BigInteger denom_) {
		if (denom_.equals(BigInteger.ZERO)) {
			throw new ArithmeticException();
		}

		BigInteger gcd = numer_.gcd(denom_);

		if (denom_.signum() == gcd.signum()) {
			numer = numer_.divide(gcd);
			denom = denom_.divide(gcd);
		} else {
			numer = numer_.divide(gcd).negate();
			denom = denom_.divide(gcd).negate();
		}
	}

	Rational negate() {
		return new Rational(numer.negate(), denom);
	}

	Rational add(Rational right) {
		return new Rational(
			numer.multiply(right.denom).add(right.numer.multiply(denom)),
			denom.multiply(right.denom)
		);
	}

	Rational sub(Rational right) {
		return add(right.negate());
	}

	Rational mul(Rational right) {
		return new Rational(numer.multiply(right.numer), denom.multiply(right.denom));
	}

	Rational div(Rational right) {
		return new Rational(numer.multiply(right.denom), denom.multiply(right.numer));
	}

	double toDouble() {
		return numer.doubleValue() / denom.doubleValue();
	}

	String toString() {
		return numer + " / " + denom;
	}

	boolean isPositive() {
		return compareTo(ZERO) > 0;
	}

	boolean isNegative() {
		return compareTo(ZERO) < 0;
	}

	boolean isZero() {
		return compareTo(ZERO) == 0;
	}

	int compareTo(Rational other) {
		return numer.multiply(other.denom).compareTo(denom.multiply(other.numer));
	}

	boolean equals(Object obj) {
		if (!(obj instanceof Rational)) return false;

		Rational other = (Rational)obj;
		return numer.equals(other.numer) && denom.equals(other.denom);
	}

	int hashCode() {
		return Objects.hash(numer, denom);
	}
}

/*-----------------------------*/
/*--------  Vector2D   --------*/
/*-----------------------------*/

/* Rational 型の2次元ベクトル (immutable) */
static class Vector2D {
	final Rational x;
	final Rational y;

	Vector2D(int x_, int y_) {
		this(new Rational(x_), new Rational(y_));
	}

	Vector2D(Rational x_, Rational y_) {
		x = x_;
		y = y_;
	}

	Rational x() {
		return x;
	}

	Rational y() {
		return y;
	}

	Vector2D add(Vector2D right) {
		return new Vector2D(x().add(right.x()), y().add(right.y()));
	}

	Vector2D sub(Vector2D right) {
		return new Vector2D(x().sub(right.x()), y().sub(right.y()));
	}

	Vector2D mul(Rational scalar) {
		return new Vector2D(x().mul(scalar), y().mul(scalar));
	}

	Vector2D div(Rational scalar) {
		return new Vector2D(x().div(scalar), y().div(scalar));
	}

	/* 内積 */
	Rational dot(Vector2D right) {
		return x().mul(right.x()).add(y().mul(right.y()));
	}

	/* 外積(2ベクトルで作る平行四辺形の面積) */
	Rational cross(Vector2D right) {
		return x().mul(right.y()).sub(y().mul(right.x()));
	}

	/* ノルム2乗 */
	Rational norm2() {
		return this.dot(this);
	}

	double norm() {
		return Math.sqrt(norm2().toDouble());
	}

	/* 偏角 */
	double arg() {
		double arg = Math.atan2(y.toDouble(), x.toDouble());
		if (arg < 0) arg += TWO_PI;
		return arg;
	}

	boolean equals(Object obj) {
		if (!(obj instanceof Vector2D)) return false;

		Vector2D other = (Vector2D)obj;
		return x.equals(other.x) && y.equals(other.y);
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

/* 有向線分 (immutable) */
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

	/* 線分の中点(切り捨て) */
	Vector2D middlePoint() {
		return start.add(end).div(new Rational(2));
	}

	/* 線分を有向線分と思ったときのベクトル */
	Vector2D toVector() {
		return end.sub(start);
	}

	/* 長さの2乗 */
	Rational length2() {
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
		if (ab.cross(ap).isPositive()) return 1;
		if (ab.cross(ap).isNegative()) return -1;
		if (ab.dot(ap).isNegative()) return -2;
		if (ab.norm2().compareTo(ap.norm2()) < 0) return 2;
		return 0;
	}

	/* 2つの線分が交差しているかどうか(端点での衝突は含まない)  */
	static boolean intersects(Segment a, Segment b) {
		return ccw(a.start(), a.end(), b.start()) * ccw(a.start(), a.end(), b.end()) < 0
			&& ccw(b.start(), b.end(), a.start()) * ccw(b.start(), b.end(), a.end()) < 0;
	}

	/* 2つの線分が交差しているかどうか(端点での衝突を含む)  */
	static boolean intersectsStrictly(Segment a, Segment b) {
		return ccw(a.start(), a.end(), b.start()) * ccw(a.start(), a.end(), b.end()) <= 0
			&& ccw(b.start(), b.end(), a.start()) * ccw(b.start(), b.end(), a.end()) <= 0;
	}

	/* 2つの直線の交点(なくても無理やり返す) */
	static Vector2D intersectionPoint(Segment a, Segment b) {
		Vector2D p = a.start();
		Vector2D q = a.end();
		Vector2D r = b.start();
		Vector2D s = b.end();

		Vector2D vec_a = new Vector2D(p.y().sub(q.y()), r.y().sub(s.y()));
		Vector2D vec_b = new Vector2D(q.x().sub(p.x()), s.x().sub(r.x()));
		Vector2D vec_c = new Vector2D(p.cross(q), r.cross(s));
		Rational det = vec_a.cross(vec_b);

		if (det.isZero()) return new Segment(p, q).middlePoint();  	// 2つの直線が平行のとき: 適当に中点を返しておく
		return new Vector2D(vec_b.cross(vec_c), vec_c.cross(vec_a)).div(det);
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

	class ListReference implements Iterable<Element> {
		int from;

		ListReference(int from_) {
			from = from_;
		}

		Iterator<Element> iterator() {
			return list.get(from).iterator();
		}
	}

	List<List<Element>> list;

	Graph() {
		this(0);
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

	protected boolean isValidIndex(int index) {
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

	ListReference getList(int from) {
		return new ListReference(from);
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

/*-----------------------------*/
/*---------   Graph   ---------*/
/*-----------------------------*/

static class GraphWithVertices<T> extends Graph {
	List<T> vertices;

	GraphWithVertices() {
		this(0);
	}

	GraphWithVertices(int size) {
		super(size);
		vertices = new ArrayList<T>(size);
	}

	GraphWithVertices(GraphWithVertices other) {
		super(other);
		vertices = new ArrayList<T>(other.vertices);
	}

	GraphWithVertices(List<T> vertices_) {
		super(vertices_.size());
		vertices = new ArrayList<T>(vertices_);
	}

	void setVertex(int index, T vertex) {
		if (!isValidIndex(index)) throw new IndexOutOfBoundsException();

		vertices.set(index, vertex);
	}

	T getVertex(int index) {
		if (!isValidIndex(index)) throw new IndexOutOfBoundsException();

		return vertices.get(index);
	}

	void addVertex(T vertex) {
		super.resize(size() + 1);
		vertices.add(vertex);
	}

	void resize(int newSize) {
		int oldSize = size();
		super.resize(newSize);

		for (int i = oldSize; i < newSize; ++i) {
			vertices.add(null);
		}
	}
}
