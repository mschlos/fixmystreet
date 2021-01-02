describe('Highways England cobrand tests', function() {
    beforeEach(function() {
        cy.server();
        cy.route('POST', '**/mapserver/highways', 'fixture:highways.xml').as('highways-tilma');
        cy.route('**/report/new/ajax*').as('report-ajax');
        cy.visit('http://highwaysengland.localhost:3001/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');
        cy.wait('@highways-tilma');
    });
    it('does not allow reporting on non-road', function() {
        cy.get('#map_box').click(280, 249);
        cy.wait('@report-ajax');
        cy.contains('The selected location is not maintained by us.').should('be.visible');
    });
    it('does not allow reporting on DBFO roads', function() {
        cy.get('#map_box').click(200, 249);
        cy.wait('@report-ajax');
        cy.contains('report on roads directly maintained').should('be.visible');
    });
    it('allows reporting on other HE roads', function() {
        cy.get('#map_box').click(240, 249);
        cy.wait('@report-ajax');
        cy.get('#category_group').select('Fallen sign');
        cy.get('#form_category').should('have.value', 'Fallen sign');
    });
});
