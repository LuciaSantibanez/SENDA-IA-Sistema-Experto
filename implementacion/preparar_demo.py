"""Carga PG2 solamente en una base vacía. Nunca ejecuta la limpieza global del ZIP."""
import argparse
from pathlib import Path
import re
import time
from pi4_calcio import conectar
import os


def dividir(texto):
    # Se respeta ; dentro de literales. Los scripts de PG2 usan comentarios //.
    salida, actual, quote, comentario = [], [], None, False
    i = 0
    while i < len(texto):
        c = texto[i]
        if comentario:
            if c == '\n':
                comentario = False
                actual.append(c)
        elif quote:
            actual.append(c)
            if c == '\\' and i+1 < len(texto):
                i += 1
                actual.append(texto[i])
            elif c == quote:
                quote = None
        elif c in "'\"`":
            quote = c
            actual.append(c)
        elif texto[i:i+2] == '//':
            comentario = True
            i += 1
        elif c == ';':
            if ''.join(actual).strip():
                salida.append(''.join(actual).strip())
            actual = []
        else:
            actual.append(c)
        i += 1
    if ''.join(actual).strip():
        salida.append(''.join(actual).strip())
    return salida


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--pg2', type=Path, required=True, help='Carpeta extraída con scripts/ de PG2')
    args = p.parse_args()
    inicio = time.monotonic()
    with conectar() as driver, driver.session(database=os.getenv('NEO4J_DATABASE','neo4j')) as session:
        if session.run('MATCH (n) RETURN count(n) AS cantidad').single()['cantidad']:
            raise SystemExit('CANCELADO: la base no está vacía. No se modifica.')
        for file in sorted((args.pg2/'scripts').glob('0[0-4]_*.cypher')):
            count = 0
            for q in dividir(file.read_text(encoding='utf-8')):
                if file.name.startswith('00_') and re.search(r'\bDELETE\b',q,re.I):
                    continue
                session.run(q).consume()
                count += 1
            print(file.name, count, 'sentencias ejecutadas', flush=True)
        print('NODOS',session.run('MATCH (n) RETURN count(n) AS n').single()['n'])
        print('RELACIONES',session.run('MATCH ()-[r]->() RETURN count(r) AS n').single()['n'])
        print('TIEMPO',round(time.monotonic()-inicio,2),'s')


if __name__ == '__main__':
    main()
