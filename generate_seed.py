#!/usr/bin/env python3
"""
Genera 02_seed_data.sql para el proyecto ecommerce_db.

- Solo usa la libreria estandar (sin dependencias).
- Es reproducible: misma semilla => mismo archivo.
- Garantiza coherencia: ordenes.total = suma de subtotales del detalle,
  y stock_actual refleja las ventas no canceladas.

Uso:
    python generate_seed.py                 # escribe 02_seed_data.sql
    python generate_seed.py --clientes 500 --ordenes 5000
"""
import argparse
import random
from datetime import datetime, timedelta

# ----------------------------- Parametros ----------------------------------
p = argparse.ArgumentParser()
p.add_argument("--clientes", type=int, default=600)
p.add_argument("--ordenes", type=int, default=1500)
p.add_argument("--seed", type=int, default=42)
p.add_argument("--salida", default="02_seed_data.sql")
args = p.parse_args()

random.seed(args.seed)

FECHA_INI = datetime(2025, 1, 1)
FECHA_FIN = datetime(2026, 10, 31, 23, 59, 59)
HOY = datetime(2026, 11, 3)

NOMBRES = ["Juan", "María", "Carlos", "Ana", "Lucas", "Sofía", "Martín", "Lucía",
           "Diego", "Valentina", "Pablo", "Camila", "Nicolás", "Julieta", "Federico",
           "Florencia", "Matías", "Agustina", "Sebastián", "Paula", "Tomás", "Carolina"]
APELLIDOS = ["Pérez", "Gómez", "López", "Martínez", "Rodríguez", "Fernández", "García",
             "González", "Sánchez", "Romero", "Díaz", "Álvarez", "Torres", "Ruiz",
             "Acosta", "Benítez", "Medina", "Herrera", "Suárez", "Molina"]
CIUDADES = [("Buenos Aires", "11"), ("Córdoba", "351"), ("Rosario", "341"),
            ("Mendoza", "261"), ("Mar del Plata", "223"), ("San Carlos de Bariloche", "294"),
            ("Tucumán", "381"), ("La Plata", "221"), ("Salta", "387"), ("Neuquén", "299")]
# Peso de cada ciudad (las grandes concentran mas clientes)
PESO_CIUDAD = [30, 12, 12, 8, 7, 4, 7, 8, 5, 7]

CATEGORIAS = [
    ("Tecnología", "Dispositivos electrónicos, computación y accesorios"),
    ("Hogar y Muebles", "Artículos para el confort y decoración del hogar"),
    ("Indumentaria", "Ropa y calzado de temporada"),
    ("Deportes", "Equipamiento y accesorios deportivos"),
    ("Libros y Papelería", "Libros, útiles y artículos de oficina"),
]

# (nombre, categoria_id, precio_actual, stock_minimo)
PRODUCTOS = [
    ('Notebook Gamer 15.6"', 1, 1250000, 3), ("Notebook Ultraliviana 14\"", 1, 980000, 3),
    ("Mouse Inalámbrico Ergonómico", 1, 25000, 10), ("Teclado Mecánico RGB", 1, 65000, 5),
    ('Monitor 27" 144Hz', 1, 420000, 4), ("Auriculares Bluetooth", 1, 78000, 8),
    ("Webcam Full HD", 1, 42000, 6), ("Disco SSD 1TB", 1, 95000, 6),
    ("Silla de Oficina Ejecutiva", 2, 180000, 2), ("Lámpara de Escritorio LED", 2, 35000, 5),
    ("Escritorio Melamina 120cm", 2, 210000, 3), ("Biblioteca 5 Estantes", 2, 150000, 3),
    ("Juego de Sábanas Queen", 2, 48000, 6), ("Organizador Multiuso", 2, 18000, 10),
    ("Campera Impermeable Deportiva", 3, 95000, 4), ("Zapatillas Running", 3, 120000, 6),
    ("Jean Slim Fit", 3, 55000, 8), ("Remera Algodón Premium", 3, 22000, 12),
    ("Buzo con Capucha", 3, 48000, 8), ("Mochila Urbana 25L", 3, 52000, 6),
    ("Pelota de Fútbol N°5", 4, 32000, 8), ("Set de Mancuernas 20kg", 4, 68000, 4),
    ("Colchoneta de Yoga", 4, 24000, 10), ("Bicicleta Rodado 29", 4, 520000, 2),
    ("Bidón Térmico 1L", 4, 19000, 12), ("Cuaderno Universitario A4", 5, 4500, 30),
    ("Set de Lapiceras x12", 5, 6800, 25), ("Libro: Python para Análisis de Datos", 5, 38000, 6),
    ("Libro: SQL Práctico", 5, 29000, 6), ("Agenda 2026", 5, 12000, 15),
]

ESTADOS_HIST = [("Entregado", 90), ("Cancelado", 6), ("Enviado", 2), ("Procesando", 1), ("Pendiente", 1)]


def q(s):
    """Escapa comillas simples para SQL."""
    return "'" + s.replace("\\", "\\\\").replace("'", "''") + "'"


def pick(pares):
    return random.choices([a for a, _ in pares], weights=[w for _, w in pares])[0]


# ----------------------------- Clientes -------------------------------------
clientes = []
usados = set()
for i in range(1, args.clientes + 1):
    nom, ape = random.choice(NOMBRES), random.choice(APELLIDOS)
    ciudad, cod = random.choices(CIUDADES, weights=PESO_CIUDAD)[0]
    email = f"{nom}.{ape}{i}@email.com".lower()
    for a, b in (("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n")):
        email = email.replace(a, b)
    n_dig = 10 - len(cod)
    tel = f"+549{cod}{random.randint(10 ** (n_dig - 1) * 4, 10 ** (n_dig - 1) * 6 - 1)}"
    registro = FECHA_INI + timedelta(days=random.randint(0, 600), seconds=random.randint(0, 86399))
    clientes.append((i, nom, ape, email, tel, ciudad, registro))

# Pareto: pocos clientes concentran muchas compras (clientes recurrentes)
pesos_cliente = [1 / (i ** 0.55) for i in range(1, args.clientes + 1)]
random.shuffle(pesos_cliente)

# ----------------------------- Ordenes y detalle ----------------------------
# Estacionalidad: mas ventas en Nov/Dic y algo en Jul (vacaciones de invierno)
PESO_MES = {1: 0.9, 2: 0.8, 3: 0.9, 4: 0.9, 5: 1.0, 6: 1.0,
            7: 1.2, 8: 0.9, 9: 1.0, 10: 1.1, 11: 1.6, 12: 1.9}
dias = []
d = FECHA_INI
while d <= FECHA_FIN:
    dias.append(d)
    d += timedelta(days=1)
pesos_dia = [PESO_MES[x.month] * (1.0 + 0.3 * ((x - FECHA_INI).days / 670)) for x in dias]  # tendencia creciente

INFLACION_MENSUAL = 0.025  # precio historico = precio actual descontado por inflacion


def precio_historico(precio_actual, fecha):
    meses = (FECHA_FIN.year - fecha.year) * 12 + (FECHA_FIN.month - fecha.month)
    return round(precio_actual / ((1 + INFLACION_MENSUAL) ** meses), 2)


ordenes, detalles = [], []
vendidas = {i: 0 for i in range(1, len(PRODUCTOS) + 1)}  # unidades vendidas no canceladas
detalle_id = 1

# Productos populares (los baratos se venden mas unidades)
pesos_prod = [1 / (pr[2] ** 0.35) for pr in PRODUCTOS]

fechas_orden = sorted(
    random.choices(dias, weights=pesos_dia, k=args.ordenes)
)
for orden_id, dia in enumerate(fechas_orden, start=1):
    fecha = dia + timedelta(seconds=random.randint(8 * 3600, 23 * 3600))
    cli = random.choices(range(1, args.clientes + 1), weights=pesos_cliente)[0]

    # Estado segun antiguedad
    antig = (HOY - fecha).days
    if antig > 20:
        estado = pick(ESTADOS_HIST)
    elif antig > 7:
        estado = pick([("Entregado", 55), ("Enviado", 35), ("Cancelado", 6), ("Procesando", 4)])
    else:
        estado = pick([("Pendiente", 40), ("Procesando", 35), ("Enviado", 20), ("Cancelado", 5)])

    n_items = random.choices([1, 2, 3, 4], weights=[55, 28, 12, 5])[0]
    prods = random.choices(range(1, len(PRODUCTOS) + 1), weights=pesos_prod, k=n_items)
    prods = list(dict.fromkeys(prods))  # sin repetir producto dentro de una orden

    total = 0.0
    for pid in prods:
        precio_actual = PRODUCTOS[pid - 1][2]
        cant = random.choices([1, 2, 3], weights=[75, 18, 7])[0]
        if precio_actual > 300000:
            cant = 1
        pu = precio_historico(precio_actual, fecha)
        total += cant * pu
        detalles.append((detalle_id, orden_id, pid, cant, pu))
        detalle_id += 1
        if estado != "Cancelado":
            vendidas[pid] += cant
    ordenes.append((orden_id, cli, fecha, estado, round(total, 2)))

# Coherencia temporal: el cliente se registra antes de su primera compra
primera = {}
for oid, cli, fe, _, _ in ordenes:
    primera.setdefault(cli, fe)
clientes = [
    (i, n, a, e, t, c,
     (primera[i] - timedelta(days=random.randint(0, 60), seconds=random.randint(0, 3600)))
     if i in primera else r)
    for i, n, a, e, t, c, r in clientes
]
reg = {c[0]: c[6] for c in clientes}
assert all(reg[cli] <= fe for _, cli, fe, _, _ in ordenes), "Registro posterior a una orden"

# ----------------------------- Stock coherente ------------------------------
# stock_actual = lo que queda tras las ventas. ~20% de productos quedan bajo el minimo
# para que el reporte de alertas de stock devuelva resultados.
productos = []
for pid, (nom, cat, precio, smin) in enumerate(PRODUCTOS, start=1):
    if random.random() < 0.22:
        restante = random.randint(0, smin)           # alerta de reposicion
    else:
        restante = smin + random.randint(5, 40)
    productos.append((pid, nom, cat, precio, restante, smin, vendidas[pid] + restante))

# ----------------------------- Chequeos de coherencia -----------------------
suma_det = {}
for _, oid, _, cant, pu in detalles:
    suma_det[oid] = suma_det.get(oid, 0) + round(cant * pu, 2)
for oid, _, _, _, total in ordenes:
    assert abs(suma_det[oid] - total) < 0.01, f"Total inconsistente en orden {oid}"
assert all(pr[4] >= 0 for pr in productos)

# ----------------------------- Escritura ------------------------------------
def fmt_dt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def insertar(f, tabla, cols, filas, lote=500):
    for i in range(0, len(filas), lote):
        f.write(f"INSERT INTO {tabla} ({', '.join(cols)}) VALUES\n")
        f.write(",\n".join("(" + ", ".join(fila) + ")" for fila in filas[i:i + lote]))
        f.write(";\n\n")


with open(args.salida, "w", encoding="utf-8") as f:
    f.write("-- ============================================================\n")
    f.write("-- 02_seed_data.sql  (generado con generate_seed.py)\n")
    f.write(f"-- Clientes: {len(clientes)} | Productos: {len(productos)} | "
            f"Ordenes: {len(ordenes)} | Items: {len(detalles)}\n")
    f.write("-- Datos 100% ficticios. Reproducible con --seed " + str(args.seed) + "\n")
    f.write("-- ============================================================\n\n")
    f.write("USE ecommerce_db;\n\n")

    insertar(f, "categorias", ["categoria_id", "nombre_categoria", "descripcion"],
             [[str(i), q(n), q(d)] for i, (n, d) in enumerate(CATEGORIAS, start=1)])

    insertar(f, "clientes",
             ["cliente_id", "nombre", "apellido", "email", "telefono", "ciudad", "pais", "fecha_registro"],
             [[str(i), q(n), q(a), q(e), q(t), q(c), q("Argentina"), q(fmt_dt(r))]
              for i, n, a, e, t, c, r in clientes])

    insertar(f, "productos",
             ["producto_id", "nombre", "categoria_id", "precio", "stock_actual", "stock_minimo"],
             [[str(i), q(n), str(c), f"{pr:.2f}", str(s), str(m)]
              for i, n, c, pr, s, m, _ in productos])

    insertar(f, "ordenes",
             ["orden_id", "cliente_id", "fecha_orden", "estado_orden", "total"],
             [[str(o), str(c), q(fmt_dt(fe)), q(es), f"{t:.2f}"] for o, c, fe, es, t in ordenes])

    insertar(f, "detalle_ordenes",
             ["detalle_id", "orden_id", "producto_id", "cantidad", "precio_unitario"],
             [[str(d), str(o), str(p_), str(c), f"{pu:.2f}"] for d, o, p_, c, pu in detalles])

alertas = sum(1 for pr in productos if pr[4] <= pr[5])
cancel = sum(1 for o in ordenes if o[3] == "Cancelado")
print(f"OK -> {args.salida}")
print(f"  clientes={len(clientes)}  productos={len(productos)}  ordenes={len(ordenes)}  items={len(detalles)}")
print(f"  productos en alerta de stock={alertas}  ordenes canceladas={cancel}")
