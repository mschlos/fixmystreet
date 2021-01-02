describe('Highways England tests', function() {
    it('report as defaults to body', function() {
        cy.server();
        cy.route('**/mapserver/highways*', 'fixture:highways.xml').as('highways-tilma');
        cy.route('**/report/new/ajax*', 'fixture:highways-ajax.json').as('report-ajax');
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');
        cy.get('#map_box').click(240, 249);
        cy.wait('@report-ajax');
        cy.wait('@highways-tilma');
        cy.get('#highways').should('contain', 'M6');
        cy.get('#js-councils_text').should('contain', 'Highways England');
        cy.get('#single_body_only').should('have.value', 'Highways England');
        cy.get('#form_category').should('contain', 'Sign issue');
        cy.get('#js-not-highways').click();
        cy.get('#js-councils_text').should('contain', 'Borsetshire');
        cy.get('#single_body_only').should('have.value', '');
        cy.get('#form_category').should('contain', 'Abandoned vehicles');
        cy.get('#js-highways').click({ force: true });
        cy.get('#js-councils_text').should('contain', 'Highways England');
        cy.get('#single_body_only').should('have.value', 'Highways England');
        cy.get('#form_category').should('contain', 'Sign issue');
        cy.get('#category_group').select('Sign issue');
        cy.get('#form_category').should('have.value', 'Sign issue');
    });
});
