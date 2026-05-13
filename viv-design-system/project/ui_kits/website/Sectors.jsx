function SectorTile({ name, tone }) {
  return (
    <figure className="viv-sector">
      <div className="viv-sector__media" style={{ background: tone }}>
        <span className="viv-sector__glyph">{name.charAt(0)}</span>
      </div>
      <figcaption>{name}</figcaption>
    </figure>
  );
}

function Sectors() {
  const sectors = [
    { name: 'Transport', tone: 'linear-gradient(160deg,#1a2230,#3a4759)' },
    { name: 'Luxe',      tone: 'linear-gradient(160deg,#2b2418,#5c4a30)' },
    { name: 'Industrie', tone: 'linear-gradient(160deg,#1e1e1e,#4a4a4a)' },
    { name: 'Service',   tone: 'linear-gradient(160deg,#1a2c28,#3c5b54)' },
    { name: 'Retail',    tone: 'linear-gradient(160deg,#2b1a28,#5c3c55)' },
    { name: 'Santé',     tone: 'linear-gradient(160deg,#18262b,#3b5c67)' },
  ];
  return (
    <section className="viv-section viv-section--tinted" id="secteurs">
      <header className="viv-section__head">
        <span className="viv-eyebrow">Nos secteurs</span>
        <h2 className="viv-h2">Une expertise <em>sectorielle</em> éprouvée.</h2>
        <p className="viv-section__lead">
          Du transport au luxe, de l'industrie à la santé, en passant par les services et le retail,
          nous collaborons avec des clients solidement installés et connaissons les spécificités
          de chaque environnement.
        </p>
      </header>
      <div className="viv-sector-grid">
        {sectors.map(s => <SectorTile key={s.name} {...s} />)}
      </div>
    </section>
  );
}
window.Sectors = Sectors;
